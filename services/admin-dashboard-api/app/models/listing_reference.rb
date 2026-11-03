class ListingReference < ApplicationRecord
  belongs_to :tenant
  belongs_to :product
end
