require "rails_helper"

RSpec.describe "Platform admin API workflow", type: :request do
  self.use_transactional_tests = false

  before do
    @admin = User.create!(
      email: "api-admin-#{SecureRandom.hex(5)}@example.test",
      password: "password123",
      is_admin: true,
      platform_admin: true
    )
    @owner = User.create!(
      email: "api-owner-#{SecureRandom.hex(5)}@example.test",
      password: "password123"
    )
    @category = Category.create!(name: "Admin API #{SecureRandom.hex(4)}")
    @product = Product.create!(
      name: "Admin API product",
      description: "Admin workflow test product",
      category: @category
    )
    sign_in_admin
  end

  after do
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

    @cart&.destroy! if @cart&.persisted?
    product_ids = @products.to_a.map(&:id)
    category_ids = @categories.to_a.map(&:id)
    discount_ids = @discounts.to_a.map(&:id)
    PaperTrail::Version.where(item_type: "Product", item_id: product_ids).delete_all
    Product.where(id: product_ids).delete_all
    PaperTrail::Version.where(item_type: "Discount", item_id: discount_ids).delete_all
    Discount.where(id: discount_ids).delete_all
    PaperTrail::Version.where(item_type: "Category", item_id: category_ids).delete_all
    Category.where(id: category_ids).delete_all
    [ @admin, @owner ].compact.each { |user| user.destroy! if user.persisted? }
  end

  it "lists resources, validates changes, and returns not-found responses" do
    @categories = [ @category, Category.create!(name: "Admin API peer #{SecureRandom.hex(4)}") ]
    @products = [ @product ]
    @discounts = [ Discount.create!(code: "API#{SecureRandom.hex(4)}", percentage: 10) ]

    get "/api/v1/admin/products"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include(
      a_hash_including(
        "category_id" => @category.id,
        "products" => include(a_hash_including("id" => @product.id, "name" => @product.name))
      )
    )

    get "/api/v1/admin/discounts"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).map { |discount| discount.fetch("id") }).to include(@discounts.first.id)

    post "/api/v1/admin/categories", params: { category: { name: "" } }
    expect(response).to have_http_status(:unprocessable_content)

    patch "/api/v1/admin/categories/#{@category.id}", params: {
      category: { name: @categories.last.name }
    }
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/admin/products", params: {
      product: { name: "Missing category", category_id: -1 }
    }
    expect(response).to have_http_status(:unprocessable_content)

    patch "/api/v1/admin/products/#{@product.id}", params: {
      product: { category_id: -1 }
    }
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/admin/discounts", params: {
      discount: { code: "", percentage: 0 }
    }
    expect(response).to have_http_status(:unprocessable_content)

    patch "/api/v1/admin/discounts/#{@discounts.first.id}", params: {
      discount: { percentage: 0 }
    }
    expect(response).to have_http_status(:unprocessable_content)

    delete "/api/v1/admin/categories/-1"
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/admin/products/-1"
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/admin/discounts/-1"
    expect(response).to have_http_status(:not_found)
  end

  it "blocks product deletion while listed and safely handles destroy failures" do
    @categories = [ @category ]
    @products = [ @product ]
    @tenant = Tenant.create!(
      user: @owner,
      name: "Admin API store",
      slug: "admin-dashboard-api-#{SecureRandom.hex(4)}"
    )
    TenantDatabase.provision!(@tenant)

    listing = TenantDatabase.switch(@tenant) do
      ProductListing.create!(product_id: @product.id, price: 4, stock_quantity: 3)
    end
    @reference = ListingReference.create!(
      tenant: @tenant,
      product: @product,
      tenant_listing_id: listing.id,
      price: listing.price,
      stock_quantity: listing.stock_quantity
    )

    delete "/api/v1/admin/products/#{@product.id}"
    expect(response).to have_http_status(:unprocessable_content)

    @reference.destroy!
    @reference = nil

    unlisted_product = Product.create!(
      name: "Unlisted product",
      description: "Can be removed after checking tenant databases",
      category: @category
    )
    @products << unlisted_product
    delete "/api/v1/admin/products/#{unlisted_product.id}"
    expect(response).to have_http_status(:ok)
    @products.delete(unlisted_product)

    failed_delete_product = Product.create!(
      name: "Failed delete product",
      description: "Exercise the destroy error response",
      category: @category
    )
    @products << failed_delete_product
    allow_any_instance_of(Product).to receive(:destroy!)
      .and_raise(ActiveRecord::RecordNotDestroyed.new("Deletion blocked"))
    delete "/api/v1/admin/products/#{failed_delete_product.id}"
    expect(response).to have_http_status(:unprocessable_content)

    empty_category = Category.create!(name: "Failed delete category #{SecureRandom.hex(3)}")
    @categories << empty_category
    allow_any_instance_of(Category).to receive(:destroy!)
      .and_raise(ActiveRecord::RecordNotDestroyed.new("Deletion blocked"))
    delete "/api/v1/admin/categories/#{empty_category.id}"
    expect(response).to have_http_status(:unprocessable_content)

    discount = Discount.create!(code: "DESTROY#{SecureRandom.hex(4)}", percentage: 10)
    @discounts = [ discount ]
    allow_any_instance_of(Discount).to receive(:destroy!)
      .and_raise(ActiveRecord::RecordNotDestroyed.new("Deletion blocked"))
    delete "/api/v1/admin/discounts/#{discount.id}"
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects unauthenticated admin API requests" do
    delete "/localFind/logout"

    get "/api/v1/admin/products"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to eq("error" => "Unauthorized. Admin access only.")
  end

  def sign_in_admin
    post "/localFind/login", params: { email: @admin.email, password: "password123" }
    expect(response).to have_http_status(:redirect)
  end
end
