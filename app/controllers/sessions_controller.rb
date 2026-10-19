class SessionsController < ApplicationController
  def new; end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id

      # If logging in via 'Admin Login' OR user already owns a tenant store
      if params[:admin_login] == "true" || user.tenant.present?
        if user.tenant.present?
          redirect_to product_listings_path, notice: "Welcome back to your store dashboard!"
        else
          redirect_to new_tenant_path, notice: "Please set up your store profile."
        end
      else
        # Regular user / shopper login
        redirect_to root_path, notice: "Logged in successfully!"
      end
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully!"
  end
end