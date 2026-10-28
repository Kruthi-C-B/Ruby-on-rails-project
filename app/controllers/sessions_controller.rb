class SessionsController < ApplicationController
  before_action :set_mfe_entry

  def new; end

  def create
    user = User.find_by(email: params[:email])

    if user && user.authenticate(params[:password])
      # --- AUDIT: SUCCESSFUL LOGIN ---
      LoginAudit.create!(
        user: user,
        email: params[:email],
        ip_address: request.remote_ip,
        status: "success"
      )

      session[:user_id] = user.id

      # 1. Platform Owner (Super Admin) Logic
      if user.is_admin?
        redirect_to "/admin/dashboard", notice: "Welcome to the Platform Admin Dashboard!"

      # 2. Existing Store Owner (Tenant) Logic
      elsif params[:admin_login] == "true" || user.tenant.present?
        if user.tenant.present?
          redirect_to root_path, notice: "Welcome back to your store dashboard!"
        else
          redirect_to new_tenant_path, notice: "Please set up your store profile."
        end

      # 3. Regular Shopper Logic
      else
        redirect_to root_path, notice: "Logged in successfully!"
      end

    elsif user
      # --- AUDIT: FAILED LOGIN (Wrong Password) ---
      LoginAudit.create!(
        user: user,
        email: params[:email],
        ip_address: request.remote_ip,
        status: "failure",
        failure_reason: "invalid_password"
      )

      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity

    else
      # --- AUDIT: FAILED LOGIN (User Not Found) ---
      LoginAttempt.create!(
    email: params[:email],
    ip_address: request.remote_ip,
    user_agent: request.user_agent,
    status: "failure",
    failure_reason: "user_not_found",
    login_timestamp: Time.current
  )

      flash.now[:alert] = "Invalid email or password."
  render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully!"
  end

  private

  def set_mfe_entry
    @mfe_entry = "authentication"
  end
end
