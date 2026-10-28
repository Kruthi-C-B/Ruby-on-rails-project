module Api
  module V1
    class ProductsController < BaseController
      def index
        products = Product.joins(:listing_references).includes(:category).distinct
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

      def show
        product = Product.includes(:category).find(params[:id])
        references = ListingReference.includes(:tenant).where(product_id: product.id)
        listings = references.map do |reference|
          listing = reference.product_listing
          {
            id: listing.id,
            listingReferenceId: reference.id,
            storeName: reference.tenant.name,
            storeAddress: reference.tenant.address,
            price: listing.price,
            stock: listing.stock_quantity
          }
        end

        recommendations = []
        if references.any?
          cart_ids = CartItem.where(listing_reference_id: references.first.id).select(:cart_id)
          recommended_ids = CartItem
            .where(cart_id: cart_ids)
            .where.not(listing_reference_id: references.first.id)
            .group(:listing_reference_id)
            .order(Arel.sql("SUM(cart_items.quantity) DESC"))
            .limit(3)
            .pluck(:listing_reference_id)

          recommendations = ListingReference.includes(:tenant, :product).where(id: recommended_ids).map do |reference|
            {
              id: reference.tenant_listing_id,
              listingReferenceId: reference.id,
              name: reference.product.name,
              price: reference.price,
              storeName: reference.tenant.name
            }
          end
        end

        render json: {
          id: product.id,
          name: product.name,
          description: product.description,
          category: product.category.name,
          listings: listings,
          recommendations: recommendations
        }
      end
    end
  end
end
