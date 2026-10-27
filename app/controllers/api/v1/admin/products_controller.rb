class Api::V1::Admin::ProductsController < Api::V1::Admin::BaseController
  def index
    products = Product.eager_load(:category).order("categories.name ASC, products.name ASC")
    grouped_products = products.group_by(&:category).map do |category, category_products|
      {
        category_id: category.id,
        category_name: category.name,
        products: category_products.map do |product|
          {
            id: product.id,
            name: product.name,
            description: product.description
          }
        end
      }
    end

    render json: grouped_products
  end

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
