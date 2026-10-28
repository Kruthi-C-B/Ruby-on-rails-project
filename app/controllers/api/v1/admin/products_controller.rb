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

  def update
    product = Product.find(params[:id])
    if product.update(product_params)
      render json: product, status: :ok
    else
      render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    product = Product.find(params[:id])
    if ListingReference.exists?(product_id: product.id) || tenant_product_records_exist?(product.id)
      return render json: {
        errors: [ "Cannot delete a product that is listed by a store or appears in purchase history." ]
      }, status: :unprocessable_entity
    end

    product.destroy!
    render json: { message: "Product deleted." }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Product not found." ] }, status: :not_found
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => error
    render json: { errors: [ error.message ] }, status: :unprocessable_entity
  end

  private

  def tenant_product_records_exist?(product_id)
    Tenant.all.any? do |tenant|
      TenantDatabase.switch(tenant) do
        ProductListing.exists?(product_id: product_id) ||
          PurchaseHistory.exists?(product_id: product_id)
      end
    end
  end

  def product_params
    params.require(:product).permit(:name, :description, :category_id)
  end
end
