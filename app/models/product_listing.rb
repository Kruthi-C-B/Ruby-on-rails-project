class ProductListing < ApplicationRecord
  has_paper_trail
  belongs_to :product

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :product_id, uniqueness: {
    message: "is already listed in your store. Please edit the existing listing instead."
  }
end
