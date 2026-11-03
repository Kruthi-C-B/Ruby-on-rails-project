module Api
  module V1
    class AuthTokensController < ApplicationController
      def show
        return render json: { errors: [ "Not logged in" ] }, status: :unauthorized unless logged_in?

        render json: { token: LocalFindPramata::ServiceTokens.issue(user: current_user, service: params[:service]) }
      rescue LocalFindPramata::ServiceTokens::UnknownService
        render json: { errors: [ "Unknown token service" ] }, status: :bad_request
      end
    end
  end
end
