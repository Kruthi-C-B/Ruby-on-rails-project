class CatalogController < ApplicationController
  def index
    @current_state = {
      loggedIn: logged_in?,
      storeName: current_tenant&.name
    }
  end
end
