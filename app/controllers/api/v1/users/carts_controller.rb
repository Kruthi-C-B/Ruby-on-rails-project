class Api::V1::Users::CartsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    return render_not_logged_in unless current_user

    cart = current_user.carts.find_by(status: "pending") || current_user.carts.create!(status: "pending")
    render json: cart_payload(cart), status: :ok
  end

  def apply_discount
    return render_not_logged_in unless current_user

    cart = current_user.carts.find_by(status: "pending")
    return render json: { error: "No active cart found" }, status: :not_found unless cart

    discount = Discount.find_by(code: params[:code])
    return render json: { error: "Invalid code" }, status: :unprocessable_entity unless discount

    cart.update!(discount: discount)
    render json: cart_payload(cart), status: :ok
  end

  def checkout
    return render_not_logged_in unless current_user

    cart = current_user.carts.find_by(status: "pending")
    cart ||= current_user.carts.find_by(status: "ordered")
    return render json: { error: "Cart is empty" }, status: :unprocessable_entity unless cart

    purchase_reference = CheckoutService.new(cart).call
    render json: { message: "Order successful!", purchase_reference: purchase_reference }, status: :ok
  rescue CheckoutService::CheckoutError => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def orders
    return render_not_logged_in unless current_user

    purchases = Tenant.all.flat_map do |tenant|
      TenantDatabase.switch(tenant) do
        PurchaseHistory.where(user_id: current_user.id).where.not(status: "pending").to_a
      end
    end
    products = Product.where(id: purchases.map(&:product_id).uniq).index_by(&:id)
    grouped_purchases = purchases.group_by(&:purchase_reference)

    render json: grouped_purchases.map { |reference, order_items|
      {
        id: reference,
        status: order_items.map(&:status).uniq.join(", "),
        updated_at: order_items.map(&:updated_at).max,
        total_price: order_items.sum(&:total_price),
        discount_amount: order_items.sum(&:discount_amount),
        cart_items: order_items.map { |item|
          {
            id: item.id,
            quantity: item.quantity,
            unit_price: item.unit_price,
            discount_amount: item.discount_amount,
            total_price: item.total_price,
            product_listing: {
              id: item.product_listing_id,
              product: {
                id: item.product_id,
                name: products[item.product_id]&.name || "Deleted product"
              }
            }
          }
        }
      }
    }.sort_by { |order| order[:updated_at] }.reverse
  end

  private

  def cart_payload(cart)
    items = cart.cart_items.includes(listing_reference: [ :tenant, :product ]).map do |item|
      reference = item.listing_reference
      listing = reference.product_listing
      {
        id: item.id,
        cart_id: item.cart_id,
        listing_reference_id: reference.id,
        quantity: item.quantity,
        unit_price: item.unit_price,
        product_listing: {
          id: listing.id,
          price: listing.price,
          stock_quantity: listing.stock_quantity,
          product: {
            id: reference.product.id,
            name: reference.product.name,
            description: reference.product.description
          }
        }
      }
    end

    {
      id: cart.id,
      status: cart.status,
      items: items,
      subtotal: cart.subtotal,
      discount_amount: cart.discount_amount,
      total_price: cart.total_price,
      discount_percentage: cart.discount&.percentage
    }
  end

  def render_not_logged_in
    render json: { error: "Not logged in" }, status: :unauthorized
  end
end
