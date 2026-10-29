class AdminSecurityController < ApplicationController
  before_action :require_login
  before_action :require_admin

  def show
  end

  private

  def require_admin
    return if current_user&.is_admin?

    render "errors/restricted", status: :forbidden
  end
end
