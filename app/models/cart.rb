# class Cart < ApplicationRecord
#   belongs_to :user
#   belongs_to :discount
# end

class Cart < ApplicationRecord
  has_paper_trail

  belongs_to :user, optional: true # optional if you allow guest checkouts
  belongs_to :discount, optional: true
  has_many :cart_items
  has_many :listing_references, through: :cart_items

  def subtotal
    cart_items.sum(BigDecimal("0")) do |item|
      item.unit_price * item.quantity
    end.round(2)
  end

  def discount_amount
    return BigDecimal("0.00") unless discount

    (subtotal * discount.percentage / 100).round(2)
  end

  def total_price
    (subtotal - discount_amount).round(2)
  end
end
