module Api
  module V1
    class AuthTokensController < ApplicationController
      def show
        return render json: { errors: [ "Not logged in" ] }, status: :unauthorized unless logged_in?

        payload = {
          user_id: current_user.id,
          email: current_user.email,
          is_admin: current_user.is_admin?,
          exp: 5.minutes.from_now.to_i
        }

        token = JWT.encode(payload, ENV.fetch("AUDIT_API_KEY"), "HS256")
        render json: { token: token }
      end
    end
  end
end