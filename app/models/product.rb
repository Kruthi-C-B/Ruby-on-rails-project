class Product < ApplicationRecord
  belongs_to :category
  has_many :product_listings, dependent: :destroy
  has_many :tenants, through: :product_listings
end