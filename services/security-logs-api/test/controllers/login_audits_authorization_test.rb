require "test_helper"

class LoginAuditsAuthorizationTest < ActionDispatch::IntegrationTest
  test "rejects requests without a token" do
    get "/api/v1/security/login_audits"

    assert_response :unauthorized
  end

  test "rejects a valid token without the admin role" do
    token = JWT.encode(
      { user_id: 1, is_admin: false, exp: 5.minutes.from_now.to_i },
      ENV.fetch("AUDIT_API_KEY"),
      "HS256"
    )

    get "/api/v1/security/login_audits", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
  end
end
