class ApplicationController < ActionController::API
  before_action :authenticate!

  private

  def authenticate!
    scheme, token = request.headers["Authorization"].to_s.split(" ", 2)
    unless scheme == "Bearer" && token.present?
      return render json: { errors: [ "Missing or invalid token" ] }, status: :unauthorized
    end

    @claims = JWT.decode(token, ENV.fetch("AUDIT_API_KEY"), true, algorithm: "HS256").first
  rescue JWT::DecodeError
    render json: { errors: [ "Missing or invalid token" ] }, status: :unauthorized
  end

  def require_admin!
    return if @claims["is_admin"] == true

    render json: { errors: [ "Admins only" ] }, status: :forbidden
  end
end
