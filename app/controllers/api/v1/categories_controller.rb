module Api
  module V1
    class CategoriesController < BaseController
      skip_before_action :require_api_login!

      def index
        render json: Category.order(:name).select(:id, :name)
      end
    end
  end
end
