class Product < ApplicationRecord
  has_paper_trail
  belongs_to :category
  has_many :listing_references
end
