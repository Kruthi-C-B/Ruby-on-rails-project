
class SessionsController < ApplicationController
  rate_limit to: 10,
             within: 3.minutes,
             by: -> {
               [
                 request.remote_ip,
                 params[:email].to_s.downcase
               ]
             },
             only: :create

  def new
  end

  def create
    user = User.find_by(email: params[:email])

    if user && user.authenticate(params[:password])

      # Audit: successful login
      LoginAudit.create!(
        user: user,
        email: params[:email],
        ip_address: request.remote_ip,
        status: "success"
      )

      # SECURITY: Start a fresh session
      reset_session
      session[:user_id] = user.id

      # 1. Platform Owner (Super Admin)
      if user.is_admin?
        redirect_to "/localFind/admin/dashboard",
                    notice: "Welcome to the Platform Admin Dashboard!"

      # 2. Existing Store Owner
      elsif params[:admin_login] == "true" || user.tenant.present?
        if user.tenant.present?
          redirect_to local_find_path,
                      notice: "Welcome back to your store dashboard!"
        else
          redirect_to "/localFind/tenant",
                      notice: "Please set up your store profile."
        end

      # 3. Regular Shopper
      else
        redirect_to local_find_path,
                    notice: "Logged in successfully!"
      end

    elsif user

      # Audit: wrong password
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

      # Audit: user not found
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
    # SECURITY: Clear the entire session
    reset_session

    redirect_to local_find_path,
                notice: "Logged out successfully!"
  end
end
