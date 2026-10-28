class Api::V1::Admin::CategoriesController < Api::V1::Admin::BaseController
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
      render json: category, status: :ok
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
    render json: { message: "Category deleted." }, status: :ok
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
