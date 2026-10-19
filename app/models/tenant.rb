class Tenant < ApplicationRecord
  belongs_to :user
  has_many :product_listings, dependent: :destroy
  has_many :products, through: :product_listings
end