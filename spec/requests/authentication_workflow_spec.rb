require "rails_helper"

RSpec.describe "Account authentication workflow", type: :request do
  self.use_transactional_tests = false

  it "redirects the legacy admin dashboard path to the prefixed route" do
    get "/admin/dashboard"

    expect(response).to redirect_to("/localFind/admin/dashboard")
  end

  after do
    (@users.to_a + [ @user ]).compact.uniq.each do |user|
      user.destroy! if user.persisted?
    end
    LoginAttempt.where(email: @email).delete_all if @email
  end

  it "registers a shopper, exposes the signed-in state, and logs out" do
    @email = "workflow-shopper-#{SecureRandom.hex(5)}@example.test"

    get "/localFind/signup"
    expect(response).to have_http_status(:ok)

    get "/localFind/admin/security"
    expect(response).to have_http_status(:forbidden)

    post "/localFind/signup", params: {
      user: {
        email: @email,
        password: "password123",
        password_confirmation: "password123"
      },
      account_type: "shopper"
    }

    expect(response).to have_http_status(:redirect)
    expect(response).to redirect_to("/localFind/products")

    @user = User.find_by!(email: @email)

    get "/api/v1/me"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq("logged_in" => true, "is_admin" => false)

    get "/localFind/admin/security"
    expect(response).to have_http_status(:forbidden)

    delete "/localFind/logout"
    expect(response).to have_http_status(:redirect)

    get "/api/v1/me"
    expect(JSON.parse(response.body)).to eq("logged_in" => false, "is_admin" => false)

    post "/localFind/login", params: { email: @email, password: "password123" }
    expect(response).to redirect_to("/localFind")
    expect(LoginAudit.where(user: @user, status: "success")).to exist

    get "/api/v1/me"
    expect(JSON.parse(response.body)).to eq("logged_in" => true, "is_admin" => false)
  end

  it "rejects an invalid password and records the failed login" do
    @email = "workflow-login-#{SecureRandom.hex(5)}@example.test"
    @user = User.create!(email: @email, password: "password123")

    post "/localFind/login", params: { email: @email, password: "wrong-password" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(LoginAudit.where(user: @user, status: "failure", failure_reason: "invalid_password")).to exist

    get "/api/v1/me"
    expect(JSON.parse(response.body)).to eq("logged_in" => false, "is_admin" => false)
  end

  it "routes admin and store-owner logins and records unknown users" do
    @email = "workflow-admin-#{SecureRandom.hex(5)}@example.test"
    @user = User.create!(
      email: @email,
      password: "password123",
      is_admin: true,
      platform_admin: true
    )
    @users = [ @user ]

    get "/localFind/login"
    expect(response).to have_http_status(:ok)

    post "/localFind/login", params: { email: @email, password: "password123" }
    expect(response).to redirect_to("/localFind/admin/dashboard")

    get "/localFind/admin/security"
    expect(response).to have_http_status(:ok)

    delete "/localFind/logout"
    expect(response).to redirect_to("/localFind")

    @email = "workflow-owner-#{SecureRandom.hex(5)}@example.test"
    @user = User.create!(email: @email, password: "password123")
    @users << @user
    post "/localFind/login", params: {
      email: @email,
      password: "password123",
      admin_login: "true"
    }
    expect(response).to redirect_to("/localFind/tenant")

    get "/localFind/tenant"
    expect(response).to have_http_status(:ok)

    get "/localFind"
    expect(response).to have_http_status(:ok)

    delete "/localFind/logout"
    post "/localFind/login", params: {
      email: "missing-#{SecureRandom.hex(5)}@example.test",
      password: "password123"
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(LoginAttempt.where(failure_reason: "user_not_found")).to exist

    post "/localFind/signup", params: {
      user: {
        email: @email,
        password: "password123",
        password_confirmation: "mismatch"
      }
    }
    expect(response).to have_http_status(:unprocessable_content)

    @email = "workflow-store-owner-#{SecureRandom.hex(5)}@example.test"
    post "/localFind/signup", params: {
      user: {
        email: @email,
        password: "password123",
        password_confirmation: "password123"
      },
      account_type: "owner"
    }
    expect(response).to redirect_to("/localFind/tenant")
    @users << User.find_by!(email: @email)
  end

  it "routes an existing store owner back to the catalog" do
    @email = "workflow-existing-owner-#{SecureRandom.hex(5)}@example.test"
    @user = User.create!(email: @email, password: "password123")
    @tenant = Tenant.create!(
      user: @user,
      name: "Existing Workflow Store",
      slug: "existingworkflow#{SecureRandom.hex(4).tr('0-9', 'abcdefghij')}"
    )

    post "/localFind/login", params: { email: @email, password: "password123" }
    expect(response).to redirect_to("/localFind")
  ensure
    @tenant&.destroy! if @tenant&.persisted?
  end

  it "enforces tenant setup on a protected HTML action" do
    CatalogController.before_action :require_tenant, only: :index

    get "/localFind"
    expect(response).to have_http_status(:forbidden)

    @email = "workflow-tenant-guard-#{SecureRandom.hex(5)}@example.test"
    @user = User.create!(email: @email, password: "password123")
    post "/localFind/login", params: { email: @email, password: "password123" }
    expect(response).to have_http_status(:redirect)

    get "/localFind"
    expect(response).to redirect_to("/localFind/tenant")

    @tenant = Tenant.create!(
      user: @user,
      name: "Guarded Store",
      slug: "guardedstore#{SecureRandom.hex(4).tr('0-9', 'abcdefghij')}"
    )
    get "/localFind"
    expect(response).to have_http_status(:ok)
  ensure
    CatalogController.skip_before_action :require_tenant, only: :index
    @tenant&.destroy! if @tenant&.persisted?
  end
end
