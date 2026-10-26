class Discount < ApplicationRecord
  has_paper_trail
  has_many :carts
end
