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

    reference = ListingReference.find_by(id: params[:listing_reference_id])
    unless reference
      return render json: { errors: [ "Product listing not found." ] }, status: :not_found
    end

    quantity = Integer(params[:quantity].to_s, 10)
    if quantity <= 0
      return render json: { errors: [ "Quantity must be greater than zero." ] }, status: :unprocessable_entity
    end

    listing = reference.product_listing
    cart = current_user.carts.find_by(status: "pending") || current_user.carts.create!(status: "pending")
    cart_item = cart.cart_items.find_or_initialize_by(listing_reference: reference)
    new_quantity = (cart_item.quantity || 0) + quantity
    if new_quantity > listing.stock_quantity
      return render json: { errors: [ "The requested quantity exceeds available stock." ] },
                    status: :unprocessable_entity
    end

    cart_item.unit_price ||= listing.price
    cart_item.quantity = new_quantity

    if cart_item.save
      render json: cart_item, status: :created
    else
      render json: { errors: cart_item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ArgumentError, TypeError
    render json: { errors: [ "Quantity must be a positive whole number." ] }, status: :unprocessable_entity
  end
end
