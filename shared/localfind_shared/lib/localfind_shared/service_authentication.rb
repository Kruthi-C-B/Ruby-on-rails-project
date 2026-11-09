require "active_support/concern"

module LocalFindShared
  module ServiceAuthentication
    extend ActiveSupport::Concern

    included do
      class_attribute :localfind_service_name, instance_predicate: false
      before_action :authenticate_localfind_service_token!
    end

    class_methods do
      def authenticates_localfind_service(service)
        self.localfind_service_name = service
      end
    end

    private

    def authenticate_localfind_service_token!
      scheme, token = request.headers["Authorization"].to_s.split(" ", 2)
      unless scheme == "Bearer" && token.present?
        return render json: { errors: [ "Missing or invalid token" ] }, status: :unauthorized
      end

      @localfind_service_claims = ServiceTokens.verify(token: token, service: self.class.localfind_service_name)
    rescue ServiceTokens::InvalidToken
      render json: { errors: [ "Missing or invalid token" ] }, status: :unauthorized
    end

    def require_localfind_admin!
      return if @localfind_service_claims&.fetch("is_admin", false) == true

      render json: { errors: [ "Admins only" ] }, status: :forbidden
    end
  end
end
