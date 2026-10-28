class RegistrationsController < ApplicationController
  before_action :set_mfe_entry

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
        redirect_to "/tenant", notice: "Account created! Now set up your store profile."
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

  def set_mfe_entry
    @mfe_entry = "authentication"
  end
end
