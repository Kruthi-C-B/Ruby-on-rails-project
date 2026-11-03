class ListingService
  Result = Struct.new(:listing, :errors, keyword_init: true)

  def initialize(tenant)
    @tenant = tenant
  end

  def create(attributes:)
    TenantDatabase.switch(@tenant) do
      listing = ProductListing.new(attributes)
      unless listing.save
        next Result.new(listing: nil, errors: listing.errors.full_messages)
      end

      reference = ListingReference.find_or_initialize_by(
        tenant: @tenant,
        product_id: listing.product_id
      )
      reference.sync_from_listing!(listing)

      Result.new(listing: listing, errors: [])
    end
  end

  def update(id:, attributes:)
    TenantDatabase.switch(@tenant) do
      listing = ProductListing.find(id)
      unless listing.update(attributes)
        next Result.new(listing: nil, errors: listing.errors.full_messages)
      end

      reference = ListingReference.find_by!(
        tenant: @tenant,
        tenant_listing_id: listing.id
      )
      reference.sync_from_listing!(listing)

      Result.new(listing: listing, errors: [])
    end
  end
end
