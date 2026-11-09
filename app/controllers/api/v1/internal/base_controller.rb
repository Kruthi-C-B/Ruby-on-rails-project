module Api
  module V1
    module Internal
      class BaseController < ActionController::API
        include LocalFindShared::ServiceAuthentication
        authenticates_localfind_service "admin-dashboard-api"
        before_action :require_localfind_admin!
      end
    end
  end
end
