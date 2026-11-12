class AdminDashboardController < ApplicationController
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


# before_action is a Rails callback.  tell me if some things are pre built in rails and what things im doing manually and should i do it everytime i create and all in simple
