class Api::V1::Admin::BaseController < Api::V1::BaseController
  skip_before_action :verify_authenticity_token
  before_action :require_admin!

  private

  def require_admin!
    return if current_user&.is_admin?

    render_error("Admin access only", status: :forbidden)
  end
end
