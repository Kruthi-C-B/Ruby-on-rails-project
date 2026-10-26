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
            listings = current_user.tenant.product_listings.includes(product: :category)
            render json: listings.as_json(include: { product: { include: :category } }), status: :ok
          end

          def create
            listing = current_user.tenant.product_listings.build(listing_params)
            if listing.save
              render json: listing.as_json(include: { product: { include: :category } }), status: :created
            else
              render json: { errors: listing.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            listing = current_user.tenant.product_listings.find(params[:id])
            if listing.update(listing_params)
              render json: listing.as_json(include: { product: { include: :category } }), status: :ok
            else
              render json: { errors: listing.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            listing = current_user.tenant.product_listings.find(params[:id])
            listing.destroy
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

            listing_ids = current_user.tenant.product_listings.pluck(:id)

            purchased_items = CartItem
              .joins(:cart)
              .includes(cart: :user, product_listing: :product)
              .where(product_listing_id: listing_ids, carts: { status: "ordered" })
              .order("carts.updated_at DESC")

            total_ordered = purchased_items
              .distinct
              .count(:cart_id)

            total_items = purchased_items.sum(&:quantity)

            render json: {
              metrics: {
                total_ordered: total_ordered,
                total_items: total_items
              },
              purchase_history: purchased_items.map do |item|
                {
                   purchaser_email: item.cart.user&.email,
                  id: item.id,
                  date: item.cart.updated_at,
                  cart_id: item.cart_id,
                  product_name: item.product_listing.product.name,
                  quantity: item.quantity,
                  unit_price: item.unit_price,
                  total: item.unit_price * item.quantity
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

          def handle_duplicate_listing
            render json: { errors: [ "This product is already listed in your store. Please edit the existing listing instead." ] }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
