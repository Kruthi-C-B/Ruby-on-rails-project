require "test_helper"

class LoginAuditsAuthorizationTest < ActionDispatch::IntegrationTest
  test "rejects requests without a token" do
    get "/api/v1/security/login_audits"

    assert_response :unauthorized
  end

  test "rejects a valid token without the admin role" do
    get "/api/v1/security/login_audits", headers: authorization_header(is_admin: false)

    assert_response :forbidden
  end

  test "accepts a platform admin role claim" do
    get "/api/v1/security/login_audits", headers: authorization_header

    assert_response :success
  end

  test "rejects expired tokens" do
    get "/api/v1/security/login_audits", headers: authorization_header(exp: 1.minute.ago.to_i)

    assert_response :unauthorized
  end

  test "rejects a token signed for the admin dashboard backend" do
    token = JWT.encode(
      {
        user_id: 1,
        email: "admin@example.test",
        is_admin: true,
        aud: "security-logs-api",
        exp: 5.minutes.from_now.to_i
      },
      "foreign-service-test-signing-key",
      "HS256"
    )

    get "/api/v1/security/login_audits", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
  end

  test "database account can read audits but cannot read users or write audit rows" do
    connection = ActiveRecord::Base.connection

    assert_nothing_raised do
      connection.select_value("SELECT id FROM login_audits LIMIT 1")
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      connection.select_value("SELECT email FROM users LIMIT 1")
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      connection.execute(
        "INSERT INTO login_audits (user_id, created_at, updated_at) VALUES (1, NOW(), NOW())"
      )
    end
    grants = connection.select_values("SHOW GRANTS")
    assert grants.any? { |grant| grant.include?("login_audits") }
    assert grants.none? { |grant| grant.include?("categories") || grant.include?("users") }
  end

  private

  def authorization_header(is_admin: true, exp: 5.minutes.from_now.to_i)
    token = JWT.encode(
      {
        user_id: 1,
        email: "admin@example.test",
        is_admin: is_admin,
        aud: "security-logs-api",
        exp: exp
      },
      ENV.fetch("SECURITY_LOGS_JWT_SECRET"),
      "HS256"
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
