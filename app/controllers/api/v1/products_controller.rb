module Api
  module V1
    class ProductsController < BaseController
      # GET /api/v1/products?query=...&category_id=...
      def index
        products = Product.joins(:product_listings).includes(:category).distinct
        products = products.where("products.name LIKE ?", "%#{params[:query]}%") if params[:query].present?
        products = products.where(category_id: params[:category_id]) if params[:category_id].present?

        render json: products.order(:name).map { |product|
          {
            id: product.id,
            name: product.name,
            description: product.description,
            category: product.category.name
          }
        }
      end

      # GET /api/v1/products/:id
      def show
        product = Product.includes(:category).find(params[:id])
        listings = product.product_listings.includes(:tenant)

        # 1. Grab the primary listing to base our clustering recommendations on
        primary_listing = listings.first

        # 2. Map the recommended listings into a clean JSON array
        recommendations = if primary_listing
                            primary_listing.frequently_bought_together.map do |rec_listing|
                              {
                                id: rec_listing.id,
                                name: rec_listing.product.name,
                                price: rec_listing.price,
                                storeName: rec_listing.tenant.name
                              }
                            end
        else
                            []
        end

        render json: {
          id: product.id,
          name: product.name,
          description: product.description,
          category: product.category.name,
          listings: listings.map { |listing|
            {
              id: listing.id,
              storeName: listing.tenant.name,
              storeAddress: listing.tenant.address,
              price: listing.price,
              stock: listing.stock_quantity
            }
          },
          # 3. Inject the recommendations into the final JSON payload
          recommendations: recommendations
        }
      end
    end
  end
end
