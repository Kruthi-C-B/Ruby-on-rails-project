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

  it "issues a short-lived token with the current admin claims" do
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/api/v1/auth/token"

    expect(response).to have_http_status(:ok)
    claims = JWT.decode(
      response.parsed_body.fetch("token"),
      ENV.fetch("AUDIT_API_KEY"),
      true,
      algorithm: "HS256"
    ).first
    expect(claims).to include(
      "user_id" => user.id,
      "email" => email,
      "is_admin" => true
    )
    expect(claims.fetch("exp")).to be_between(Time.current.to_i, 5.minutes.from_now.to_i)
  end

  it "renders the security page with the audit service URL" do
    post "/localFind/login", params: { email: email, password: "password123" }

    get "/localFind/admin/security"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('auditApiUrl: "http://127.0.0.1:3100"')
  end
end