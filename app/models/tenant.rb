class Tenant < ApplicationRecord
  belongs_to :user
  has_many :listing_references, dependent: :destroy

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-zA-Z0-9-]+\z/ }
end