class Api::V1::Admin::ProductsController < Api::V1::Admin::BaseController
  def create
    product = Product.new(product_params)
    if product.save
      render json: product, status: :created
    else
      render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private
  def product_params
    params.require(:product).permit(:name, :description, :category_id)
  end
end
