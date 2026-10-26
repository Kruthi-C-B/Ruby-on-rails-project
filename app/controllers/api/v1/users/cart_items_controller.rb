class Api::V1::Users::CartItemsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    # 1. Enforce that someone is actually logged in
    if current_user.nil?
      return render json: { errors: [ "You must be logged in to add items to a cart." ] }, status: :unauthorized
    end

    if current_user.is_admin?
            return render json: { errors: [ "Platform admins cannot add items to a cart." ] }, status: :forbidden
    end

    # 2. Securely find or create the cart attached only to the current_user
    cart = current_user.carts.find_by(status: "pending") || current_user.carts.create!(status: "pending")

    product_listing = ProductListing.find_by(id: params[:product_listing_id])

    if product_listing.nil?
      return render json: { errors: [ "Product listing not found." ] }, status: :not_found
    end

    cart_item = cart.cart_items.find_or_initialize_by(product_listing: product_listing)

    cart_item.unit_price ||= product_listing.price
    cart_item.quantity = (cart_item.quantity || 0) + params[:quantity].to_i

    if cart_item.save
      render json: cart_item, status: :created
    else
      render json: { errors: cart_item.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
