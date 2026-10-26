class Product < ApplicationRecord
  has_paper_trail
  belongs_to :category
  has_many :product_listings, dependent: :destroy
  has_many :tenants, through: :product_listings
end
