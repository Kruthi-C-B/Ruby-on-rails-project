require "rails_helper"

RSpec.describe "Audit API token endpoint", type: :request do
  self.use_transactional_tests = false

  let(:email) { "audit-token-#{SecureRandom.hex(5)}@example.test" }
  let!(:user) do
    User.create!(
      email: email,
      password: "password123",
      is_admin: true,
      platform_admin: true
    )
  end

  after do
    user.destroy! if user.persisted?
  end

  it "requires a logged-in user" do
    get "/api/v1/auth/token"

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("errors" => [ "Not logged in" ])
  end

  it "issues a short-lived token for the requested backend" do
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/api/v1/auth/token", params: { service: "admin-dashboard-api" }

    expect(response).to have_http_status(:ok)
    claims = JWT.decode(
      response.parsed_body.fetch("token"),
      ENV.fetch("ADMIN_DASHBOARD_JWT_SECRET"),
      true,
      algorithm: "HS256"
    ).first
    expect(claims).to include(
      "user_id" => user.id,
      "email" => email,
      "is_admin" => true,
      "aud" => "admin-dashboard-api"
    )
    expect(claims.fetch("exp")).to be_between(Time.current.to_i, 5.minutes.from_now.to_i)
    expect {
      JWT.decode(
        response.parsed_body.fetch("token"),
        ENV.fetch("SECURITY_LOGS_JWT_SECRET"),
        true,
        algorithm: "HS256"
      )
    }.to raise_error(JWT::VerificationError)
  end

  it "uses a different key and audience for the security logs backend" do
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/api/v1/auth/token", params: { service: "security-logs-api" }

    expect(response).to have_http_status(:ok)
    claims = JWT.decode(
      response.parsed_body.fetch("token"),
      ENV.fetch("SECURITY_LOGS_JWT_SECRET"),
      true,
      algorithm: "HS256"
    ).first
    expect(claims.fetch("aud")).to eq("security-logs-api")
  end

  it "issues an administrator claim for a platform-admin-only user" do
    user.update!(is_admin: false, platform_admin: true)
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/api/v1/auth/token", params: { service: "admin-dashboard-api" }

    expect(response).to have_http_status(:ok)
    claims = JWT.decode(
      response.parsed_body.fetch("token"),
      ENV.fetch("ADMIN_DASHBOARD_JWT_SECRET"),
      true,
      algorithm: "HS256"
    ).first
    expect(claims.fetch("is_admin")).to be(true)
  end

  it "rejects requests for an unconfigured backend" do
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/api/v1/auth/token", params: { service: "unknown-service" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to eq("errors" => [ "Unknown token service" ])
  end

  it "renders the admin dashboard mount with the micro-backend URL" do
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/localFind/admin/dashboard"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('adminApiUrl: "http://127.0.0.1:3100"')
    expect(response.body).to include('securityLogsMfeUrl: "/mfe/localfind-security-logs.js"')
    expect(response.body).to include('securityLogsApiUrl: "http://127.0.0.1:3101"')
  end
end
