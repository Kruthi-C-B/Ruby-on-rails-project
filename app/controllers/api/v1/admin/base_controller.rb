class Api::V1::Admin::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :require_admin!

  private

  def require_admin!
    # Because you are using Rails sessions, we can check current_user directly
    user = User.find_by(id: session[:user_id])
    unless user&.is_admin?
      render json: { error: "Unauthorized. Admin access only." }, status: :unauthorized
    end
  end
end
