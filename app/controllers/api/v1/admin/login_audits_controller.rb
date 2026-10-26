class Api::V1::Admin::LoginAuditsController < ApplicationController
  def index
    # 1. Enforce Admin Security
    if current_user.nil? || !current_user.is_admin?
      return render json: { error: "Unauthorized access" }, status: :forbidden
    end

    # 2. Fetch the latest 100 login attempts, including the associated user if they exist
    audits = LoginAudit.includes(:user).order(created_at: :desc).limit(100)

    # 3. Format the data for React
    render json: audits.map { |audit|
      {
        id: audit.id,
        email: audit.email,
        ip_address: audit.ip_address,
        status: audit.status,
        failure_reason: audit.failure_reason,
        created_at: audit.created_at.strftime("%Y-%m-%d %H:%M:%S"),
        user_id: audit.user_id
      }
    }, status: :ok
  end
end
