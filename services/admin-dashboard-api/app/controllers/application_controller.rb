class ApplicationController < ActionController::API
  before_action :authenticate!

  private

  def authenticate!
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    @claims = JWT.decode(token, ENV.fetch("AUDIT_API_KEY"), true, algorithm: "HS256").first
  rescue JWT::DecodeError
    render json: { errors: [ "Missing or invalid token" ] }, status: :unauthorized
  end

  def require_admin!
    return if @claims["is_admin"] == true

    render json: { errors: [ "Admins only" ] }, status: :forbidden
  end
end
