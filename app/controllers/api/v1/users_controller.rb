class Api::V1::UsersController < ApplicationController
  def me
    if current_user
      render json: { logged_in: true, is_admin: current_user.is_admin? }
    else
      render json: { logged_in: false, is_admin: false }
    end
  end
end
