module Api
  module V1
    module Admin
      class CategoriesController < ::Admin::BaseController
        def index
          render json: Category.order(:name)
        end

        def create
          category = Category.new(category_params)
          if category.save
            render json: category, status: :created
          else
            render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          category = Category.find(params[:id])
          if category.update(category_params)
            render json: category
          else
            render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          category = Category.find(params[:id])
          if category.products.exists?
            return render json: { errors: [ "Cannot delete a category that still has products. Move or delete its products first." ] },
                          status: :unprocessable_entity
          end

          category.destroy!
          render json: { message: "Category deleted." }
        rescue ActiveRecord::RecordNotFound
          render json: { errors: [ "Category not found." ] }, status: :not_found
        rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => error
          render json: { errors: [ error.message ] }, status: :unprocessable_entity
        end

        private

        def category_params
          params.require(:category).permit(:name)
        end
      end
    end
  end
end
