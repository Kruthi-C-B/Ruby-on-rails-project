class ApplicationController < ActionController::API
  include LocalFindShared::ServiceAuthentication
  authenticates_localfind_service "security-logs-api"
end
