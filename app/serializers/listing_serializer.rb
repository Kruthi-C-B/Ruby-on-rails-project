class ListingSerializer
  def self.as_json(listing, reference)
    listing.as_json(include: { product: { include: :category } }).merge(
      listing_reference_id: reference.id
    )
  end
end
