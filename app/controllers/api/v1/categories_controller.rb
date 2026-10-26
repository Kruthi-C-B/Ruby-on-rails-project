module Api
  module V1
    class CategoriesController < BaseController
      def index
        render json: Category.order(:name).select(:id, :name)
      end
    end
  end
end
