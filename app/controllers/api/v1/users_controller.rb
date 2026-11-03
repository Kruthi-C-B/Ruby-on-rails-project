class Api::V1::UsersController < ApplicationController
  def me
    user = current_user

    unless user
      return render json: {
        logged_in: false,
        is_admin: false
      }
    end

    render json: {
      logged_in: true,
      is_admin: user.is_admin?,
      tenant: user.tenant&.as_json(
        only: [ :id, :name, :slug, :address ]
      )
    }
  end
end
