class ApplicationController < ActionController::API
  include LocalFindPramata::ServiceAuthentication
  authenticates_localfind_service "admin-dashboard-api"
end
