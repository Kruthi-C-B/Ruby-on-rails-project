class Api::V1::Users::CartsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    if current_user.nil?
      return render json: { error: "Not logged in" }, status: :unauthorized
    end

    # Securely tied to the logged-in user
    cart = current_user.carts.find_by(status: "pending") || current_user.carts.create!(status: "pending")

    # Render a clean Ruby hash so you don't fight with as_json formatting
    render json: {
      id: cart.id,
      status: cart.status,
      items: cart.cart_items.as_json(include: { product_listing: { include: :product } }),
      subtotal: cart.cart_items.sum { |item| item.unit_price * item.quantity },
      total_price: cart.total_price,
      discount_percentage: cart.discount&.percentage
    }
  end

  def apply_discount
    if current_user.nil?
      return render json: { error: "Not logged in" }, status: :unauthorized
    end

    # Fetch the active cart for the CURRENT user, not Cart.first
    cart = current_user.carts.find_by(status: "pending")

    if cart.nil?
      return render json: { error: "No active cart found" }, status: :not_found
    end

    discount = Discount.find_by(code: params[:code])

    if discount
      cart.update(discount: discount)

      # Return the updated calculations back to React
      render json: {
        id: cart.id,
        status: cart.status,
        items: cart.cart_items.as_json(include: { product_listing: { include: :product } }),
        subtotal: cart.cart_items.sum { |item| item.unit_price * item.quantity },
        total_price: cart.total_price,
        discount_percentage: cart.discount.percentage
      }
    else
      render json: { error: "Invalid code" }, status: :unprocessable_entity
    end
  end

  def checkout
    if current_user.nil?
        return render json: { error: "Not logged in" }, status: :unauthorized
    end

    cart = current_user.carts.find_by(status: "pending")

    if cart.nil? || cart.cart_items.empty?
        return render json: { error: "Cart is empty" }, status: :unprocessable_entity
    end

    # Lock in the order.
    if cart.update(status: "ordered")
      render json: { message: "Order successful!" }, status: :ok
    else
      render json: { error: "Checkout failed" }, status: :unprocessable_entity
    end
  end

  def orders
    if current_user.nil?
      return render json: { error: "Not logged in" }, status: :unauthorized
    end

    # Fetch all carts that are NO LONGER pending (ordered, delivered, etc.)
    past_orders = current_user.carts.where.not(status: "pending").order(updated_at: :desc)

    # Return the orders along with their items and the total price
    render json: past_orders.as_json(
      include: {
        cart_items: { include: { product_listing: { include: :product } } }
      },
      methods: [ :total_price ]
    )
  end

  # def audit
  #   carts = current_user.carts

  #   # 1. Fetch personal metrics
  #   total_ordered = carts.where(status: "ordered").count
  #   total_items = CartItem.where(cart_id: carts.pluck(:id)).sum(:quantity)

  #   # 2. Fetch the Paper Trail audit logs for their specific carts
  #   # This tracks when their cart was created, updated (discount applied), or ordered
  #   cart_versions = PaperTrail::Version.where(item_type: "Cart", item_id: carts.pluck(:id)).order(created_at: :desc)

  #   render json: {
  #     metrics: {
  #       total_ordered: total_ordered,
  #       total_items: total_items
  #     },
  #     audit_trail: cart_versions.map do |v|
  #       {
  #         id: v.id,
  #         event: v.event.upcase, # CREATE, UPDATE, DESTROY
  #         cart_id: v.item_id,
  #         date: v.created_at.strftime("%Y-%m-%d %H:%M:%S")
  #       }
  #     end
  #   }, status: :ok
  # end
end
