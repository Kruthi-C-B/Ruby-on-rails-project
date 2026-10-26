module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound do
        render json: { errors: [ "Not found" ] }, status: :not_found
      end
    end
  end
end



# I need you to incorporate these additions into your project:
# Support for adding items to a cart, summing prices, and applying discounts.
# A paper trail for tracking products, purchases, and other data changes via the paper_trail gem.
# User login audit trails.
# Integration with the React UI.
# A global audit system to monitor product and item counts added to the cart and how people use it.
# Analysis of clustering processes in purchases to provide recommendations through MySQL grouping searches.
