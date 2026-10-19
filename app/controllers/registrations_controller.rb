class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

def create
  @user = User.new(user_params)

  if @user.save
      # Log the user in automatically
      session[:user_id] = @user.id

    # Route them based on their radio button choice
    if params[:account_type] == "owner"
        redirect_to new_tenant_path, notice: "Account created! Now set up your store profile."
    else
        redirect_to products_path, notice: "Account created successfully! Welcome to the catalog."
    end
  else
      render :new, status: :unprocessable_entity
  end
end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
