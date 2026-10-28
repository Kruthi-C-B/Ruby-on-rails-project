module Api
  module V1
    module Users
      module StoreOwners
        class ProductListingsController < ApplicationController
          skip_before_action :verify_authenticity_token
          before_action :require_store_owner

          # Catch database unique constraint violations and return as JSON
          rescue_from ActiveRecord::RecordNotUnique, with: :handle_duplicate_listing

          def index
            tenant = current_user.tenant
            listings = TenantDatabase.switch(tenant) do
              ProductListing.includes(product: :category).to_a
            end
            references = ListingReference.where(tenant: tenant).index_by(&:tenant_listing_id)

            render json: listings.map { |listing|
              serialize_listing(listing, references.fetch(listing.id))
            }, status: :ok
          end

          def create
            tenant = current_user.tenant
            listing, errors = TenantDatabase.switch(tenant) do
              listing = ProductListing.new(listing_params)
              if listing.save
                reference = ListingReference.find_or_initialize_by(
                  tenant: tenant,
                  product_id: listing.product_id
                )
                reference.sync_from_listing!(listing)
                [ listing, nil ]
              else
                [ nil, listing.errors.full_messages ]
              end
            end

            if listing
              reference = ListingReference.find_by!(tenant: tenant, tenant_listing_id: listing.id)
              render json: serialize_listing(listing, reference), status: :created
            else
              render json: { errors: errors }, status: :unprocessable_entity
            end
          end

          def update
            tenant = current_user.tenant
            listing, errors = TenantDatabase.switch(tenant) do
              listing = ProductListing.find(params[:id])
              if listing.update(listing_params)
                ListingReference.find_by!(tenant: tenant, tenant_listing_id: listing.id)
                  .sync_from_listing!(listing)
                [ listing, nil ]
              else
                [ nil, listing.errors.full_messages ]
              end
            end

            if listing
              reference = ListingReference.find_by!(tenant: tenant, tenant_listing_id: listing.id)
              render json: serialize_listing(listing, reference), status: :ok
            else
              render json: { errors: errors }, status: :unprocessable_entity
            end
          end

          def destroy
            tenant = current_user.tenant
            reference = ListingReference.find_by!(tenant: tenant, tenant_listing_id: params[:id])
            if reference.cart_items.exists?
              return render json: {
                errors: [ "A product listing referenced by a cart or purchase cannot be removed." ]
              }, status: :conflict
            end

            deleted = TenantDatabase.switch(tenant) do
              listing = ProductListing.find(params[:id])
              if PurchaseHistory.exists?(product_listing_id: listing.id)
                next false
              end

              listing.destroy!
              true
            end

            return render json: {
              errors: [ "A product listing with purchase history cannot be removed." ]
            }, status: :conflict unless deleted

            reference.destroy!
            render json: { message: "Listing removed" }, status: :ok
          end

          #         def analytics
          # unless current_user&.tenant
          #   return render json: { error: "Store profile required" },
          #                 status: :forbidden
          # end

          # # Get only product listings belonging to this shop owner
          # listings = current_user.tenant.product_listings
          # listing_ids = listings.pluck(:id)

          # # Find carts containing products from this store
          # relevant_cart_items = CartItem.where(product_listing_id: listing_ids)
          # relevant_cart_ids = relevant_cart_items.distinct.pluck(:cart_id)

          # # Count completed orders that contain this store's products
          # total_ordered = Cart.where(
          #   id: relevant_cart_ids,
          #   status: "ordered"
          # ).count

          # # Count units of this store's products in completed orders
          # total_items = relevant_cart_items
          #   .where(cart_id: Cart.where(status: "ordered").select(:id))
          #   .sum(:quantity)

          # # Retrieve cart history for the relevant carts
          # cart_versions = PaperTrail::Version
          #   .where(item_type: "Cart", item_id: relevant_cart_ids)
          #   .order(created_at: :desc)

          # render json: {
          #   metrics: {
          #     total_ordered: total_ordered,
          #     total_items: total_items
          #   },
          #   audit_trail: cart_versions.map do |version|
          #     {
          #       id: version.id,
          #       event: version.event.upcase,
          #       cart_id: version.item_id,
          #       date: version.created_at.strftime("%Y-%m-%d %H:%M:%S")
          #     }
          #   end
          # }, status: :ok
          #         end


          def analytics
            return render json: { error: "Store profile required" },
                          status: :forbidden unless current_user&.tenant

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
            render json: { error: "Forbidden. Store profile required." }, status: :forbidden if current_user&.tenant.nil?
          end

          def listing_params
            params.require(:product_listing).permit(:product_id, :price, :stock_quantity)
          end

          def serialize_listing(listing, reference)
            listing.as_json(include: { product: { include: :category } }).merge(
              listing_reference_id: reference.id
            )
          end

          def handle_duplicate_listing
            render json: { errors: [ "This product is already listed in your store. Please edit the existing listing instead." ] }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
