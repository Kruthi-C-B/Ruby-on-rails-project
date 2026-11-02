require "rails_helper"

RSpec.describe "Store owner and public catalog workflow", type: :request do
  self.use_transactional_tests = false

  before do
    @owner = User.create!(
      email: "workflow-owner-#{SecureRandom.hex(5)}@example.test",
      password: "password123"
    )
    @category = Category.create!(name: "Workflow category #{SecureRandom.hex(4)}")
    @product = Product.create!(
      name: "Workflow product",
      description: "A product in the public catalog",
      category: @category
    )
  end

  after do
    cleanup_tenant
    if @product
      PaperTrail::Version.where(item_type: "Product", item_id: @product.id).delete_all
      @product.destroy! if @product.persisted?
    end
    if @category
      PaperTrail::Version.where(item_type: "Category", item_id: @category.id).delete_all
      @category.destroy! if @category.persisted?
    end
    @owner&.destroy! if @owner&.persisted?
  end

  it "creates a store profile, manages a listing, and exposes it in the filtered catalog" do
    sign_in_owner

    post "/api/v1/users/store_owners/tenant", params: {
      tenant: {
        name: "Workflow Store",
        slug: "workflow-store-#{SecureRandom.hex(4)}",
        address: "123 Main Street"
      }
    }

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig("tenant", "name")).to eq("Workflow Store")
    @tenant = @owner.reload.tenant

    patch "/api/v1/users/store_owners/tenant", params: {
      tenant: { address: "456 Updated Street" }
    }
    expect(response).to have_http_status(:ok)
    expect(@tenant.reload.address).to eq("456 Updated Street")

    patch "/api/v1/users/store_owners/tenant", params: {
      tenant: { slug: "not a valid slug" }
    }
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/users/store_owners/product_listings", params: {
      product_listing: { product_id: @product.id, price: "12.50", stock_quantity: 8 }
    }
    expect(response).to have_http_status(:created)
    listing_response = JSON.parse(response.body)
    expect(listing_response.dig("product", "name")).to eq(@product.name)
    expect(listing_response.fetch("price").to_f).to eq(12.5)
    listing_id = listing_response.fetch("id")
    reference = @tenant.listing_references.find_by!(tenant_listing_id: listing_id)

    post "/api/v1/users/store_owners/product_listings", params: {
      product_listing: { product_id: @product.id, price: "12.50", stock_quantity: 8 }
    }
    expect(response).to have_http_status(:unprocessable_content)

    get "/api/v1/categories"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).map { |category| category.fetch("id") }).to include(@category.id)

    get "/api/v1/products", params: { category_id: @category.id }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).map { |product| product.fetch("id") }).to eq([ @product.id ])

    get "/api/v1/products/#{@product.id}"
    expect(response).to have_http_status(:ok)
    product_details = JSON.parse(response.body)
    expect(product_details.fetch("listings")).to include(
      a_hash_including(
        "listingReferenceId" => reference.id,
        "storeName" => "Workflow Store",
        "storeAddress" => "456 Updated Street"
      )
    )

    get "/api/v1/products/-1"
    expect(response).to have_http_status(:not_found)

    get "/api/v1/users/store_owners/product_listings"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).map { |listing| listing.fetch("id") }).to include(listing_id)

    patch "/api/v1/users/store_owners/product_listings/#{listing_id}", params: {
      product_listing: { price: "-1", stock_quantity: 6 }
    }
    expect(response).to have_http_status(:unprocessable_content)

    patch "/api/v1/users/store_owners/product_listings/#{listing_id}", params: {
      product_listing: { price: "15.00", stock_quantity: 6 }
    }
    expect(response).to have_http_status(:ok)
    reference.reload
    expect(reference.price).to eq(BigDecimal("15.00"))
    expect(reference.stock_quantity).to eq(6)

    get "/api/v1/users/store_owners/analytics"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("metrics")).to eq("total_ordered" => 0, "total_items" => 0)

    cart = @owner.carts.create!(status: "pending")
    cart_item = cart.cart_items.create!(
      listing_reference: reference,
      quantity: 1,
      unit_price: reference.price
    )
    delete "/api/v1/users/store_owners/product_listings/#{listing_id}"
    expect(response).to have_http_status(:conflict)
    cart_item.destroy!
    PaperTrail::Version.where(item_type: "Cart", item_id: cart.id).delete_all
    cart.destroy!

    purchase_id = TenantDatabase.switch(@tenant) do
      PurchaseHistory.create!(
        user_id: @owner.id,
        product_listing_id: listing_id,
        product_id: @product.id,
        quantity: 1,
        unit_price: reference.price,
        total_price: reference.price,
        purchase_reference: SecureRandom.uuid,
        status: "successful",
        purchased_at: Time.current
      ).id
    end
    delete "/api/v1/users/store_owners/product_listings/#{listing_id}"
    expect(response).to have_http_status(:conflict)
    TenantDatabase.switch(@tenant) do
      PaperTrail::Version.where(item_type: "PurchaseHistory", item_id: purchase_id).delete_all
      PurchaseHistory.where(id: purchase_id).delete_all
    end

    delete "/api/v1/users/store_owners/product_listings/#{listing_id}"
    expect(response).to have_http_status(:ok)

    get "/api/v1/products", params: { query: "Workflow" }
    expect(response).to have_http_status(:ok)

    get "/api/v1/products"
    expect(JSON.parse(response.body)).not_to include(a_hash_including("id" => @product.id))
  end

  it "prevents a signed-in user without a store profile from managing listings" do
    sign_in_owner

    get "/api/v1/users/store_owners/product_listings"

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to eq("error" => "Forbidden. Store profile required.")

    patch "/api/v1/users/store_owners/tenant", params: { tenant: { name: "Missing store" } }
    expect(response).to have_http_status(:not_found)
  end

  it "requires login and rejects invalid store profile creation" do
    post "/api/v1/users/store_owners/tenant", params: {
      tenant: { name: "Unauthorized", slug: "unauthorized" }
    }
    expect(response).to have_http_status(:unauthorized)

    sign_in_owner
    post "/api/v1/users/store_owners/tenant", params: {
      tenant: { name: "Invalid store", slug: "invalid slug" }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns a conflict-shaped validation response for database duplicate races" do
    sign_in_owner
    post "/api/v1/users/store_owners/tenant", params: {
      tenant: {
        name: "Duplicate Race Store",
        slug: "duplicate-race-#{SecureRandom.hex(4)}"
      }
    }
    expect(response).to have_http_status(:created)
    @tenant = @owner.reload.tenant

    allow_any_instance_of(ProductListing).to receive(:save)
      .and_raise(ActiveRecord::RecordNotUnique)
    post "/api/v1/users/store_owners/product_listings", params: {
      product_listing: { product_id: @product.id, price: "12.50", stock_quantity: 8 }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include(
      "This product is already listed in your store. Please edit the existing listing instead."
    )
  end

  it "cleans up a tenant database when provisioning fails after database creation" do
    sign_in_owner
    slug = "provision-failure-#{SecureRandom.hex(4)}"

    allow(Apartment::Tenant).to receive(:create).and_wrap_original do |original, tenant_slug, &block|
      original.call(tenant_slug, &block)
      raise Apartment::TenantExists, "simulated provisioning failure"
    end

    post "/api/v1/users/store_owners/tenant", params: {
      tenant: { name: "Provision failure store", slug: slug }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("Unable to initialize the store database.")
    expect(@owner.reload.tenant).to be_nil

    database_name = Apartment::Tenant.environmentify(slug)
    expect(Apartment.connection.select_values("SHOW DATABASES")).not_to include(database_name)
  end

  def sign_in_owner
    post "/localFind/login", params: { email: @owner.email, password: "password123" }
    expect(response).to have_http_status(:redirect)
  end

  def cleanup_tenant
    tenant = @tenant || @owner&.reload&.tenant
    return unless tenant

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
end
