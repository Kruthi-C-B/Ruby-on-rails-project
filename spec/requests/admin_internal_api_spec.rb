require "rails_helper"

RSpec.describe "Admin-only internal API", type: :request do
  def service_token(is_admin: true, audience: "admin-dashboard-api", secret: "ADMIN_DASHBOARD_JWT_SECRET")
    JWT.encode(
      {
        user_id: 1,
        email: "admin@example.test",
        is_admin: is_admin,
        aud: audience,
        exp: 5.minutes.from_now.to_i
      },
      ENV.fetch(secret),
      "HS256"
    )
  end

  it "accepts an admin-dashboard token for tenant-data requests" do
    get "/api/v1/internal/admin/product_references",
        params: { product_id: 999_999_999 },
        headers: { "Authorization" => "Bearer #{service_token}" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("in_use" => false)
  end

  it "rejects a non-admin service token" do
    get "/api/v1/internal/admin/audit_trail",
        headers: { "Authorization" => "Bearer #{service_token(is_admin: false)}" }

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a token signed for a different service" do
    get "/api/v1/internal/admin/audit_trail",
        headers: {
          "Authorization" => "Bearer #{service_token(audience: 'admin-dashboard-api', secret: 'SECURITY_LOGS_JWT_SECRET')}"
        }

    expect(response).to have_http_status(:unauthorized)
  end
end
