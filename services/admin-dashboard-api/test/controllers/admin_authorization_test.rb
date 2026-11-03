require "test_helper"

class AdminAuthorizationTest < ActionDispatch::IntegrationTest
  def test_admin_endpoint_rejects_missing_token
    get "/api/v1/admin/categories"

    assert_response :unauthorized
  end

  def test_admin_endpoint_rejects_non_admin_token
    get "/api/v1/admin/categories", headers: authorization_header(is_admin: false)

    assert_response :forbidden
  end

  def test_admin_endpoint_accepts_platform_admin_role_claim
    get "/api/v1/admin/categories", headers: authorization_header(is_admin: true)

    assert_response :success
  end

  def test_admin_endpoint_rejects_expired_token
    get "/api/v1/admin/categories", headers: authorization_header(exp: 1.minute.ago.to_i)

    assert_response :unauthorized
  end

  def test_admin_endpoint_rejects_token_missing_required_claims
    token = JWT.encode(
      { user_id: 1, is_admin: true, aud: "admin-dashboard-api", exp: 5.minutes.from_now.to_i },
      ENV.fetch("ADMIN_DASHBOARD_JWT_SECRET"),
      "HS256"
    )
    get "/api/v1/admin/categories", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
  end

  def test_products_endpoint_groups_products_by_category
    category = Category.create!(name: "Products API test #{SecureRandom.hex(6)}")
    product = Product.create!(
      category: category,
      name: "Products API test product #{SecureRandom.hex(6)}",
      description: "Test description"
    )

    get "/api/v1/admin/products", headers: authorization_header

    assert_response :success
    group = response.parsed_body.find { |item| item["category_id"] == category.id }
    assert_equal category.name, group.fetch("category_name")
    assert_equal(
      [ { "id" => product.id, "name" => product.name, "description" => product.description } ],
      group.fetch("products")
    )
  end

  def test_platform_user_output_uses_the_shared_admin_rule_without_exposing_other_columns
    user = User.new(
      id: 41,
      email: "platform-admin@example.test",
      is_admin: false,
      platform_admin: true,
      created_at: Time.current
    )
    user.define_singleton_method(:associated_tenant_id) { nil }
    relation = StubRelation.new([ user ])

    with_stubbed_query(User, :left_outer_joins, relation) do
      get "/api/v1/admin/users", headers: authorization_header
    end

    assert_response :success
    record = response.parsed_body.first
    assert_equal "Platform Admin", record.fetch("role")
    assert_equal %w[created_at email id role], record.keys.sort
  end

  def test_platform_user_query_works_with_column_restricted_database_access
    get "/api/v1/admin/users", headers: authorization_header

    assert_response :success
    assert response.parsed_body.all? { |record| (record.keys - %w[id email role created_at]).empty? }
  end

  def test_stores_response_contains_only_explicitly_serialized_fields
    tenant = Tenant.new(id: 17, name: "Fields test store", created_at: Time.current)
    tenant.define_singleton_method(:owner_email) { "owner@example.test" }
    relation = StubRelation.new([ tenant ])

    with_stubbed_query(Tenant, :joins, relation) do
      get "/api/v1/admin/stores", headers: authorization_header
    end

    assert_response :success
    record = response.parsed_body.first
    assert_equal %w[created_at id name owner_email], record.keys.sort
  end

  def test_store_and_cart_queries_work_with_column_restricted_database_access
    get "/api/v1/admin/stores", headers: authorization_header
    assert_response :success
    assert response.parsed_body.all? { |record| (record.keys - %w[id name owner_email created_at]).empty? }

    get "/api/v1/admin/cart_metrics", headers: authorization_header
    assert_response :success
    assert_equal %w[completed_carts pending_carts total_carts], response.parsed_body.keys.sort
  end

  def test_rejects_a_token_signed_for_another_backend
    token = JWT.encode(
      {
        user_id: 1,
        email: "admin@example.test",
        is_admin: true,
        aud: "admin-dashboard-api",
        exp: 5.minutes.from_now.to_i
      },
      "foreign-service-test-signing-key",
      "HS256"
    )

    get "/api/v1/admin/categories", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
  end

  def test_database_account_cannot_read_passwords_or_security_audits
    connection = ActiveRecord::Base.connection

    assert_raises(ActiveRecord::StatementInvalid) do
      connection.select_value("SELECT password_digest FROM users LIMIT 1")
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      connection.select_value("SELECT id FROM login_audits LIMIT 1")
    end
    grants = connection.select_values("SHOW GRANTS")
    assert grants.any? { |grant| grant.include?("categories") }
    assert grants.none? { |grant| grant.include?("_tenant_") }
  end

  private

  class StubRelation
    def initialize(rows)
      @rows = rows
    end

    def select(*)
      self
    end

    def order(*)
      self
    end

    def map(&block)
      @rows.map(&block)
    end
  end

  def with_stubbed_query(model, method_name, relation)
    original_method = model.method(method_name)
    model.define_singleton_method(method_name) { |*| relation }
    yield
  ensure
    model.define_singleton_method(method_name, original_method)
  end

  def authorization_header(is_admin: true, exp: 5.minutes.from_now.to_i)
    token = JWT.encode(
      {
        user_id: 1,
        email: "admin@example.test",
        is_admin: is_admin,
        aud: "admin-dashboard-api",
        exp: exp
      },
      ENV.fetch("ADMIN_DASHBOARD_JWT_SECRET"),
      "HS256"
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
