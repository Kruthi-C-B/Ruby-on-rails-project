class ApplicationController < ActionController::API
  include LocalFindShared::ServiceAuthentication
  authenticates_localfind_service "admin-dashboard-api"
end
