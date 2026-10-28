class ListingReference < ApplicationRecord
  belongs_to :tenant
  belongs_to :product
  has_many :cart_items, dependent: :restrict_with_exception

  validates :tenant_listing_id, presence: true, uniqueness: { scope: :tenant_id }
  validates :product_id, uniqueness: { scope: :tenant_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def sync_from_listing!(listing)
    update!(
      tenant_listing_id: listing.id,
      product_id: listing.product_id,
      price: listing.price,
      stock_quantity: listing.stock_quantity
    )
  end

  def product_listing
    ::TenantDatabase.switch(tenant) do
      ProductListing.find_by!(id: tenant_listing_id)
    end
  end
end
