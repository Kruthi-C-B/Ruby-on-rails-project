module Admin
  class BaseController < ApplicationController
    before_action :require_localfind_admin!
  end
end
