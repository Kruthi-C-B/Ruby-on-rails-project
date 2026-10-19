class ProductListing < ApplicationRecord
  belongs_to :tenant
  belongs_to :product

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Ensures a tenant cannot list the same product twice
  validates :product_id, uniqueness: { 
    scope: :tenant_id, 
    message: "is already listed in your store. Please edit the existing listing instead." 
  }
end