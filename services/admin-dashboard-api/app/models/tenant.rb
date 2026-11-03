class Tenant < ApplicationRecord
  belongs_to :user
  has_many :listing_references
end
