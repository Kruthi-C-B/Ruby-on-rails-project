class Discount < ApplicationRecord
  has_paper_trail
  has_many :carts

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
end
