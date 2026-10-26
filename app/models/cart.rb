# class Cart < ApplicationRecord
#   belongs_to :user
#   belongs_to :discount
# end

class Cart < ApplicationRecord
  has_paper_trail

  belongs_to :user, optional: true # optional if you allow guest checkouts
  belongs_to :discount, optional: true
  has_many :cart_items
  has_many :product_listings, through: :cart_items

  def total_price
    subtotal = cart_items.sum { |item| item.unit_price * item.quantity }
    if discount
      subtotal - (subtotal * (discount.percentage / 100))
    else
      subtotal
    end
  end
end
