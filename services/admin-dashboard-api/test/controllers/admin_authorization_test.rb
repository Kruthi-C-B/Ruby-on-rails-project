require "test_helper"

class AdminAuthorizationTest < ActionDispatch::IntegrationTest
  def test_admin_endpoint_rejects_missing_token
    get "/api/v1/admin/categories"

    assert_response :unauthorized
  end

  def test_admin_endpoint_rejects_non_admin_token
    token = JWT.encode(
      { user_id: 1, is_admin: false, exp: 5.minutes.from_now.to_i },
      ENV.fetch("AUDIT_API_KEY"),
      "HS256"
    )

    get "/api/v1/admin/categories", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
  end

  def test_products_endpoint_groups_products_by_category
    category = Category.create!(name: "Products API test #{SecureRandom.hex(6)}")
    product = Product.create!(
      category: category,
      name: "Products API test product #{SecureRandom.hex(6)}",
      description: "Test description"
    )
    token = JWT.encode(
      { user_id: 1, is_admin: true, exp: 5.minutes.from_now.to_i },
      ENV.fetch("AUDIT_API_KEY"),
      "HS256"
    )

    get "/api/v1/admin/products", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    group = response.parsed_body.find { |item| item["category_id"] == category.id }
    assert_equal category.name, group.fetch("category_name")
    assert_equal(
      [{ "id" => product.id, "name" => product.name, "description" => product.description }],
      group.fetch("products")
    )
  end
end
