module Api
  module V1
    module Users
      module StoreOwners
        class ProductListingsController < Api::V1::BaseController
          # skip_before_action :verify_authenticity_token
          before_action :require_store_owner
          rescue_from ActiveRecord::RecordNotUnique do
            render_error(
              "This product is already listed in your store. Please edit the existing listing instead.",
              status: :unprocessable_entity
            )
          end

          def index
            tenant = current_user.tenant
            listings = TenantDatabase.switch(tenant) do
              ProductListing.includes(product: :category).to_a
            end
            references = ListingReference.where(tenant: tenant).index_by(&:tenant_listing_id)

            render json: listings.map { |listing|
              ::ListingSerializer.as_json(listing, references.fetch(listing.id))
            }, status: :ok
          end

          def create
            tenant = current_user.tenant
            result = ::ListingService.new(tenant).create(attributes: listing_params)

            if result.listing
              reference = ListingReference.find_by!(tenant: tenant, tenant_listing_id: result.listing.id)
              render json: ::ListingSerializer.as_json(result.listing, reference), status: :created
            else
              render_error(result.errors, status: :unprocessable_entity)
            end
          end

          def update
            tenant = current_user.tenant
            result = ::ListingService.new(tenant).update(id: params[:id], attributes: listing_params)

            if result.listing
              reference = ListingReference.find_by!(tenant: tenant, tenant_listing_id: result.listing.id)
              render json: ::ListingSerializer.as_json(result.listing, reference), status: :ok
            else
              render_error(result.errors, status: :unprocessable_entity)
            end
          end

          def destroy
            tenant = current_user.tenant
            reference = ListingReference.find_by!(tenant: tenant, tenant_listing_id: params[:id])
            if reference.cart_items.exists?
              return render_error(
                "A product listing referenced by a cart or purchase cannot be removed.",
                status: :conflict
              )
            end

            deleted = TenantDatabase.switch(tenant) do
              listing = ProductListing.find(params[:id])
              next false if PurchaseHistory.exists?(product_listing_id: listing.id)

              listing.destroy!
              true
            end

            unless deleted
              return render_error(
                "A product listing with purchase history cannot be removed.",
                status: :conflict
              )
            end

            reference.destroy!
            render json: { message: "Listing removed" }, status: :ok
          end

          def analytics
            purchases = TenantDatabase.switch(current_user.tenant) do
              PurchaseHistory.where(status: "successful").order(purchased_at: :desc).to_a
            end
            products = Product.where(id: purchases.map(&:product_id).uniq).index_by(&:id)
            purchaser_emails = User.where(id: purchases.map(&:user_id).uniq).pluck(:id, :email).to_h

            render json: {
              metrics: {
                total_ordered: purchases.map(&:purchase_reference).uniq.size,
                total_items: purchases.sum(&:quantity)
              },
              purchase_history: purchases.map do |purchase|
                {
                  purchaser_email: purchaser_emails[purchase.user_id],
                  id: purchase.id,
                  date: purchase.purchased_at,
                  cart_id: purchase.purchase_reference,
                  product_name: products[purchase.product_id]&.name || "Deleted product",
                  quantity: purchase.quantity,
                  unit_price: purchase.unit_price,
                  total: purchase.total_price
                }
              end
            }, status: :ok
          end

          private

          def require_store_owner
            return if current_user.tenant

            render_error("Store profile required", status: :forbidden)
          end

          def listing_params
            params.require(:product_listing).permit(:product_id, :price, :stock_quantity)
          end
        end
      end
    end
  end
end
