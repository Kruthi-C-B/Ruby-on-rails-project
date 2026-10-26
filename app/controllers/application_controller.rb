class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?, :current_tenant
  before_action :set_paper_trail_whodunnit
  private

  def user_for_paper_trail
   current_user&.id
  end
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def current_tenant
    @current_tenant ||= current_user&.tenant
  end

  def require_login
    unless logged_in?
      # Render custom restricted error view directly with 403 status
      render "errors/restricted", status: :forbidden
    end
  end

  def require_tenant
    require_login
    return if performed? # Stop execution if require_login already rendered restricted page

    if logged_in? && current_tenant.nil?
      flash[:alert] = "Please create a store profile first."
      redirect_to new_tenant_path
    end
  end
end
