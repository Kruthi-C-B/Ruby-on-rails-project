class PurchaseHistory < ApplicationRecord
  has_paper_trail

  belongs_to :product_listing
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, :total_price, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_reference, presence: true
  validates :status, presence: true
end
