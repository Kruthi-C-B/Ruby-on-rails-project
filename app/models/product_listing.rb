class ProductListing < ApplicationRecord
  has_paper_trail
  belongs_to :tenant
  belongs_to :product
  has_many :cart_items

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Ensures a tenant cannot list the same product twice
  validates :product_id, uniqueness: {
    scope: :tenant_id,
    message: "is already listed in your store. Please edit the existing listing instead."
  }

  def frequently_bought_together
    # 1. Find all cart IDs that contain THIS product
    carts_with_this_item = CartItem.where(product_listing_id: id).select(:cart_id)

    # 2. Find other products in those exact same carts, group them, and sort by popularity
    ProductListing.joins(:cart_items)
                  .where(cart_items: { cart_id: carts_with_this_item })
                  .where.not(id: id) # Exclude the current product
                  .group("product_listings.id")
                  .order("COUNT(cart_items.id) DESC")
                  .limit(3)
  end
end
