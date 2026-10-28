class CatalogController < ApplicationController
  def index
    @mfe_entry = case request.path
    when "/admin/dashboard"
      "platform-admin"
    when "/product_listings", "/tenant", "/tenant/edit"
      "store-owner"
    else
      "user-application"
    end

    @current_state = {
      loggedIn: logged_in?,
      storeName: current_tenant&.name
    }
  end
end
