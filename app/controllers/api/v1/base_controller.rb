module Api
  module V1
    class BaseController < ApplicationController
      before_action :require_api_login!
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      def require_api_login!
        return if current_user

        render_error("Not logged in", status: :unauthorized)
      end

      def render_error(messages, status:)
        errors = Array(messages).compact
        errors = [ "Request failed" ] if errors.empty?
        render json: { errors: errors }, status: status
      end

      def render_not_found
        render_error("Not found", status: :not_found)
      end
    end
  end
end
