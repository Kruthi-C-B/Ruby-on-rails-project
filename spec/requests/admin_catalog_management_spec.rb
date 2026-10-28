require "rails_helper"

RSpec.describe "Platform admin catalog management", type: :request do
  self.use_transactional_tests = false

  it "allows admins to edit and delete categories, products, and discounts" do
    admin = User.create!(
      email: "catalog-admin-#{SecureRandom.hex(5)}@example.test",
      password: "password123",
      is_admin: true,
      platform_admin: true
    )
    category_id = nil
    product_id = nil
    discount_id = nil
    cart = nil

    post "/login", params: { email: admin.email, password: "password123" }
    expect(response).to have_http_status(:redirect)

    post "/api/v1/admin/categories", params: { category: { name: "CRUD Category" } }
    expect(response).to have_http_status(:created)
    category_id = JSON.parse(response.body).fetch("id")

    patch "/api/v1/admin/categories/#{category_id}", params: {
      category: { name: "Updated CRUD Category" }
    }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("name")).to eq("Updated CRUD Category")

    post "/api/v1/admin/products", params: {
      product: { name: "CRUD Product", description: "Test product", category_id: category_id }
    }
    expect(response).to have_http_status(:created)
    product_id = JSON.parse(response.body).fetch("id")

    delete "/api/v1/admin/categories/#{category_id}"
    expect(response).to have_http_status(:unprocessable_entity)

    patch "/api/v1/admin/products/#{product_id}", params: {
      product: { name: "Updated CRUD Product", description: "Updated test product", category_id: category_id }
    }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("name")).to eq("Updated CRUD Product")

    delete "/api/v1/admin/products/#{product_id}"
    expect(response).to have_http_status(:ok)
    product_id = nil

    delete "/api/v1/admin/categories/#{category_id}"
    expect(response).to have_http_status(:ok)
    category_id = nil

    post "/api/v1/admin/discounts", params: {
      discount: { code: "CRUD#{SecureRandom.hex(3)}", percentage: 10 }
    }
    expect(response).to have_http_status(:created)
    discount_id = JSON.parse(response.body).fetch("id")

    cart = admin.carts.create!(discount: Discount.find(discount_id), status: "pending")
    delete "/api/v1/admin/discounts/#{discount_id}"
    expect(response).to have_http_status(:unprocessable_content)
    cart.destroy!
    cart = nil

    patch "/api/v1/admin/discounts/#{discount_id}", params: {
      discount: { code: "UPDATED#{SecureRandom.hex(3)}", percentage: 20 }
    }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("percentage").to_f).to eq(20)

    delete "/api/v1/admin/discounts/#{discount_id}"
    expect(response).to have_http_status(:ok)
    discount_id = nil
  ensure
    Product.where(id: product_id).delete_all if product_id
    PaperTrail::Version.where(item_type: "Product", item_id: product_id).delete_all if product_id
    Category.where(id: category_id).delete_all if category_id
    Discount.where(id: discount_id).delete_all if discount_id
    PaperTrail::Version.where(item_type: "Discount", item_id: discount_id).delete_all if discount_id
    Cart.where(id: cart.id).delete_all if cart
    PaperTrail::Version.where(item_type: "Cart", item_id: cart.id).delete_all if cart
    admin&.destroy! if admin&.persisted?
  end
end
