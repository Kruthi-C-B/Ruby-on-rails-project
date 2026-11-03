module Api
  module V1
    module Admin
      class ProductsController < ::Admin::BaseController
        def index
          products = Product.eager_load(:category).order("categories.name ASC, products.name ASC")
          product_groups = products.group_by(&:category).map do |category, category_products|
            {
              category_id: category.id,
              category_name: category.name,
              products: category_products.map do |product|
                { id: product.id, name: product.name, description: product.description }
              end
            }
          end

          render json: product_groups
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
            render json: product
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
          render json: { message: "Product deleted." }
        rescue ActiveRecord::RecordNotFound
          render json: { errors: [ "Product not found." ] }, status: :not_found
        rescue MainAppInternalClient::Error => error
          Rails.logger.error("Tenant product data request failed: #{error.message}")
          render json: { errors: [ "Tenant product data is temporarily unavailable" ] },
                 status: :service_unavailable
        rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => error
          render json: { errors: [ error.message ] }, status: :unprocessable_entity
        end

        private

        def tenant_product_records_exist?(product_id)
          result = MainAppInternalClient.new(authorization: request.headers["Authorization"]).get(
            "/api/v1/internal/admin/product_references",
            params: { product_id: product_id }
          )
          result.fetch("in_use")
        end

        def product_params
          params.require(:product).permit(:name, :description, :category_id)
        end
      end
    end
  end
end
