require "rails_helper"

RSpec.describe "Shopping cart checkout", type: :request do
  self.use_transactional_tests = false

  before do
    @tenants = []
    @products = []
    @references = []
    @carts = []
    @cart_items = []
    @users = []
    @discounts = []
    @category = Category.create!(name: "Checkout #{SecureRandom.hex(5)}")
    @shopper = create_user("shopper")
  end

  after do
    CartItem.where(cart_id: @carts.map(&:id)).delete_all
    PaperTrail::Version.where(item_type: "CartItem", item_id: @cart_items.map(&:id)).delete_all
    @carts.each do |cart|
      PaperTrail::Version.where(item_type: "Cart", item_id: cart.id).delete_all
    end
    Cart.where(id: @carts.map(&:id)).delete_all

    @tenants.each do |tenant|
      database_name = Apartment::Tenant.environmentify(tenant.slug)
      if Apartment.connection.select_values("SHOW DATABASES").include?(database_name)
        TenantDatabase.switch(tenant) do
          PurchaseHistory.delete_all
          ProductListing.delete_all
          PaperTrail::Version.delete_all
        end
        Apartment::Tenant.drop(tenant.slug)
      end
      ListingReference.where(tenant_id: tenant.id).delete_all
      Tenant.where(id: tenant.id).delete_all
    end

    @products.each do |product|
      PaperTrail::Version.where(item_type: "Product", item_id: product.id).delete_all
      Product.where(id: product.id).delete_all
    end
    @discounts.each do |discount|
      PaperTrail::Version.where(item_type: "Discount", item_id: discount.id).delete_all
      Discount.where(id: discount.id).delete_all
    end
    @users.each do |user|
      LoginAudit.where(user_id: user.id).delete_all
      user.destroy! if user.persisted?
    end
    Category.where(id: @category&.id).delete_all
  end

  it "checks out items across tenant databases and returns an order reference" do
    owner = create_user("checkout-owner")
    2.times do |index|
      tenant, listing, reference = create_tenant_listing("checkout-#{index}", index + 10)
      @tenants << tenant
      @references << reference
      create_cart_item(reference, quantity: 2)
    end
    login(@shopper)

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:ok)
    response_body = JSON.parse(response.body)
    expect(response_body["message"]).to eq("Order successful!")
    expect(response_body["purchase_reference"]).to be_present

    expect(@cart.reload.status).to eq("ordered")
    @tenants.zip(@references).each do |tenant, reference|
      TenantDatabase.switch(tenant) do
        purchase = PurchaseHistory.find_by!(purchase_reference: response_body.fetch("purchase_reference"))
        expect(purchase.quantity).to eq(2)
        expect(purchase.status).to eq("successful")
        expect(purchase.product_listing_id).to eq(reference.tenant_listing_id)
        expect(ProductListing.find(reference.tenant_listing_id).stock_quantity).to eq(8)
        expect(PaperTrail::Version.where(item_type: "PurchaseHistory", item_id: purchase.id).count).to eq(2)
      end
    end
  end

  it "applies a discount across purchases through the public checkout flow" do
    tenant, listing, reference = create_tenant_listing("discount-checkout", 20.91)
    @tenants << tenant
    @references << reference
    discount = Discount.create!(code: "CHECKOUT#{SecureRandom.hex(3)}", percentage: 20)
    @discounts << discount
    create_cart_item(reference, quantity: 1, discount: discount)
    login(@shopper)

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:ok)
    purchase_reference = JSON.parse(response.body).fetch("purchase_reference")
    expect(@cart.reload.subtotal).to eq(BigDecimal("20.91"))
    expect(@cart.total_price).to eq(BigDecimal("16.73"))

    purchase = TenantDatabase.switch(tenant) do
      PurchaseHistory.find_by!(purchase_reference: purchase_reference)
    end
    expect(purchase.discount_amount).to eq(BigDecimal("4.18"))
    expect(purchase.total_price).to eq(BigDecimal("16.73"))
  end

  it "rejects checkout when the shopper is not logged in" do
    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to eq("error" => "Not logged in")
  end

  it "rejects checkout when the shopper has no cart" do
    login(@shopper)

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Cart is empty")
  end

  it "rejects checkout for an empty pending cart" do
    @cart = @shopper.carts.create!(status: "pending")
    @carts << @cart
    login(@shopper)

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Cart is empty.")
    expect(@cart.reload.status).to eq("pending")
  end

  it "rejects checkout for an already ordered cart" do
    tenant, _listing, reference = create_tenant_listing("already-ordered", 12)
    @tenants << tenant
    @references << reference
    create_cart_item(reference)
    @cart.update!(status: "ordered")
    login(@shopper)

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "This cart has already been checked out.")
    expect(@cart.reload.status).to eq("ordered")
  end

  it "rejects checkout when a product is no longer available" do
    tenant, listing, reference = create_tenant_listing("removed-listing", 12)
    @tenants << tenant
    @references << reference
    create_cart_item(reference)
    login(@shopper)
    TenantDatabase.switch(tenant) { listing.destroy! }

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "A product is no longer available.")
    expect(@cart.reload.status).to eq("pending")
  end

  it "rejects checkout when product stock is insufficient" do
    tenant, listing, reference = create_tenant_listing("insufficient-stock", 12)
    @tenants << tenant
    @references << reference
    create_cart_item(reference, quantity: 2)
    login(@shopper)
    TenantDatabase.switch(tenant) { listing.update!(stock_quantity: 1) }

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "A product does not have enough stock.")
    expect(@cart.reload.status).to eq("pending")
  end

  it "rejects a retry whose cart contents changed during checkout" do
    tenant, listing, reference = create_tenant_listing("changed-retry", 12)
    @tenants << tenant
    @references << reference
    create_cart_item(reference)
    login(@shopper)

    post "/api/v1/users/cart/checkout"
    expect(response).to have_http_status(:ok)
    purchase_reference = JSON.parse(response.body).fetch("purchase_reference")

    @cart.update!(status: "pending")
    TenantDatabase.switch(tenant) do
      PurchaseHistory.find_by!(purchase_reference: purchase_reference).update!(quantity: 2)
    end

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "The cart changed while checkout was being retried.")
  end

  def create_user(label)
    user = User.create!(
      email: "#{label}-#{SecureRandom.hex(5)}@example.test",
      password: "password123"
    )
    @users << user
    user
  end

  def login(user)
    post "/login", params: { email: user.email, password: "password123" }
    expect(response).to have_http_status(:redirect)
  end

  def create_tenant_listing(label, price)
    owner = create_user("#{label}-owner")
    tenant = Tenant.create!(
      user: owner,
      name: "#{label} store",
      slug: "#{label}-#{SecureRandom.hex(5)}"
    )
    TenantDatabase.provision!(tenant)
    product = Product.create!(
      name: "#{label} product",
      description: "Functional checkout test product",
      category: @category
    )
    @products << product
    listing = TenantDatabase.switch(tenant) do
      ProductListing.create!(product_id: product.id, price: price, stock_quantity: 10)
    end
    reference = ListingReference.create!(
      tenant: tenant,
      product: product,
      tenant_listing_id: listing.id,
      price: listing.price,
      stock_quantity: listing.stock_quantity
    )

    [ tenant, listing, reference ]
  end

  def create_cart_item(reference, quantity: 1, discount: nil)
    @cart ||= @shopper.carts.create!(status: "pending", discount: discount)
    @carts |= [ @cart ]
    item = @cart.cart_items.create!(
      listing_reference: reference,
      quantity: quantity,
      unit_price: reference.price
    )
    @cart_items << item
    item
  end
end
