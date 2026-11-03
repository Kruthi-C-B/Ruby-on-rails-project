class ApplicationController < ActionController::API
  include LocalFindPramata::ServiceAuthentication
  authenticates_localfind_service "security-logs-api"
end
