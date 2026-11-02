require "rails_helper"

RSpec.describe "Shopping cart workflow", type: :request do
  self.use_transactional_tests = false

  before do
    @owner = create_user("cart-owner")
    @shopper = create_user("cart-shopper")
    @admin = create_user("cart-admin", admin: true)
    @category = Category.create!(name: "Cart workflow #{SecureRandom.hex(4)}")
    @products = 2.times.map do |index|
      Product.create!(
        name: "Cart product #{index}",
        description: "Cart workflow product",
        category: @category
      )
    end
    @tenant = Tenant.create!(
      user: @owner,
      name: "Cart workflow store",
      slug: "cart-workflow-#{SecureRandom.hex(4)}",
      address: "10 Market Street"
    )
    TenantDatabase.provision!(@tenant)
    @references = @products.map do |product|
      listing = TenantDatabase.switch(@tenant) do
        ProductListing.create!(product_id: product.id, price: "0.03", stock_quantity: 10)
      end
      ListingReference.create!(
        tenant: @tenant,
        product: product,
        tenant_listing_id: listing.id,
        price: listing.price,
        stock_quantity: listing.stock_quantity
      )
    end
    @discount = Discount.create!(code: "CART#{SecureRandom.hex(4)}", percentage: 50)
  end

  after do
    carts = (@carts.to_a + @shopper.carts.to_a).uniq
    cart_items = (@cart_items.to_a + CartItem.where(cart_id: carts.map(&:id)).to_a).uniq
    PaperTrail::Version.where(item_type: "CartItem", item_id: cart_items.map(&:id)).delete_all
    CartItem.where(cart_id: carts.map(&:id)).delete_all
    Cart.where(id: carts.map(&:id)).find_each do |cart|
      PaperTrail::Version.where(item_type: "Cart", item_id: cart.id).delete_all
      cart.destroy!
    end

    if @tenant
      database_name = Apartment::Tenant.environmentify(@tenant.slug)
      if Apartment.connection.select_values("SHOW DATABASES").include?(database_name)
        TenantDatabase.switch(@tenant) do
          PurchaseHistory.delete_all
          ProductListing.delete_all
          PaperTrail::Version.delete_all
        end
        Apartment::Tenant.drop(@tenant.slug)
      end
      ListingReference.where(tenant_id: @tenant.id).delete_all
      @tenant.destroy! if @tenant.persisted?
    end

    @products.to_a.each do |product|
      PaperTrail::Version.where(item_type: "Product", item_id: product.id).delete_all
      product.destroy! if product.persisted?
    end
    PaperTrail::Version.where(item_type: "Discount", item_id: @discount&.id).delete_all
    @discount&.destroy! if @discount&.persisted?
    PaperTrail::Version.where(item_type: "Category", item_id: @category&.id).delete_all
    @category&.destroy! if @category&.persisted?
    [ @shopper, @owner, @admin ].compact.each { |user| user.destroy! if user.persisted? }
  end

  it "adds and discounts items, checks out, and returns purchase history" do
    expect_unauthenticated_cart_requests
    sign_in(@shopper)

    post "/api/v1/users/cart/apply_discount", params: { code: @discount.code }
    expect(response).to have_http_status(:not_found)

    get "/api/v1/users/cart"
    expect(response).to have_http_status(:ok)
    @cart = @shopper.carts.find_by!(status: "pending")
    @carts = [ @cart ]

    post "/api/v1/users/cart/apply_discount", params: { code: "MISSING" }
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/users/cart/apply_discount", params: { code: @discount.code }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("discount_percentage").to_f).to eq(50)

    post "/api/v1/users/cart/items", params: { listing_reference_id: -1, quantity: 1 }
    expect(response).to have_http_status(:not_found)

    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: "not-a-number"
    }
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: 0
    }
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: 11
    }
    expect(response).to have_http_status(:unprocessable_content)

    @cart_items = []
    @references.each do |reference|
      post "/api/v1/users/cart/items", params: {
        listing_reference_id: reference.id,
        quantity: 1
      }
      expect(response).to have_http_status(:created)
      @cart_items << CartItem.find(JSON.parse(response.body).fetch("id"))
    end

    get "/api/v1/users/cart"
    expect(response).to have_http_status(:ok)
    cart_json = JSON.parse(response.body)
    expect(cart_json.fetch("items").length).to eq(2)
    expect(cart_json.fetch("subtotal").to_f).to eq(0.06)
    expect(cart_json.fetch("discount_amount").to_f).to eq(0.03)

    get "/api/v1/products/#{@products.first.id}"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("recommendations")).to include(
      a_hash_including("name" => @products.last.name)
    )

    post "/api/v1/users/cart/checkout"
    expect(response).to have_http_status(:ok)
    expect(@cart.reload.status).to eq("ordered")

    @cart.update!(status: "pending")
    post "/api/v1/users/cart/checkout"
    expect(response).to have_http_status(:ok)
    expect(@cart.reload.status).to eq("ordered")

    get "/api/v1/users/cart/orders"
    expect(response).to have_http_status(:ok)
    orders = JSON.parse(response.body)
    expect(orders.length).to eq(1)
    expect(orders.first.fetch("cart_items").length).to eq(2)

    delete "/localFind/logout"
    sign_in(@owner)
    get "/api/v1/users/store_owners/analytics"
    expect(response).to have_http_status(:ok)
    analytics = JSON.parse(response.body)
    expect(analytics.fetch("metrics")).to eq("total_ordered" => 1, "total_items" => 2)
    expect(analytics.fetch("purchase_history").first.fetch("purchaser_email")).to eq(@shopper.email)
  end

  it "does not allow platform admins to add products to a cart" do
    sign_in(@admin)

    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: 1
    }

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body).fetch("errors")).to include("Platform admins cannot add items to a cart.")
  end

  it "returns cart-item validation errors and maps checkout record errors to the API" do
    sign_in(@shopper)
    allow_any_instance_of(CartItem).to receive(:save).and_return(false)

    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: 1
    }
    expect(response).to have_http_status(:unprocessable_content)

    get "/api/v1/users/cart"
    expect(response).to have_http_status(:ok)
    allow_any_instance_of(CheckoutService).to receive(:call)
      .and_raise(ActiveRecord::RecordNotFound, "listing disappeared")

    post "/api/v1/users/cart/checkout"
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)).to eq("error" => "listing disappeared")
  end

  it "rechecks inventory immediately before creating a purchase" do
    sign_in(@shopper)
    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: 1
    }
    expect(response).to have_http_status(:created)

    stock_reads = 0
    allow_any_instance_of(ProductListing).to receive(:stock_quantity).and_wrap_original do |original|
      stock_reads += 1
      stock_reads == 2 ? 0 : original.call
    end

    post "/api/v1/users/cart/checkout"

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)).to eq("error" => "A product does not have enough stock.")
  end

  def create_user(label, admin: false)
    User.create!(
      email: "#{label}-#{SecureRandom.hex(5)}@example.test",
      password: "password123",
      is_admin: admin,
      platform_admin: admin
    )
  end

  def sign_in(user)
    post "/localFind/login", params: { email: user.email, password: "password123" }
    expect(response).to have_http_status(:redirect)
  end

  def expect_unauthenticated_cart_requests
    get "/api/v1/users/cart"
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/users/cart/apply_discount", params: { code: @discount.code }
    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/users/cart/orders"
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/users/cart/items", params: {
      listing_reference_id: @references.first.id,
      quantity: 1
    }
    expect(response).to have_http_status(:unauthorized)
  end
end
