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


  #   def create(attributes:)
  #   Rails.logger.info "Starting listing creation"
  #   Rails.logger.info "Tenant ID: #{@tenant.id}"
  #   Rails.logger.info "Attributes: #{attributes.inspect}"

  #   TenantDatabase.switch(@tenant) do
  #     Rails.logger.info "Tenant database switched successfully"

  #     listing = ProductListing.new(attributes)

  #     Rails.logger.info "ProductListing initialized"

  #     unless listing.save
  #       Rails.logger.error "Listing validation errors: #{listing.errors.full_messages}"

  #       next Result.new(
  #         listing: nil,
  #         errors: listing.errors.full_messages
  #       )
  #     end

  #     Rails.logger.info "ProductListing saved: #{listing.id}"

  #     reference = ListingReference.find_or_initialize_by(
  #       tenant: @tenant,
  #       product_id: listing.product_id
  #     )

  #     Rails.logger.info "ListingReference initialized"

  #     reference.sync_from_listing!(listing)

  #     Rails.logger.info "ListingReference synchronized"

  #     Result.new(listing: listing, errors: [])
  #   end
  # rescue StandardError => error
  #   Rails.logger.error "LISTING CREATION FAILED"
  #   Rails.logger.error "#{error.class}: #{error.message}"
  #   Rails.logger.error error.backtrace.first(15).join("\n")

  #   raise
  # end

  def update(id:, attributes:)
    TenantDatabase.switch(@tenant) do
      listing = ProductListing.find(id)
      unless listing.update(**attributes)
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
