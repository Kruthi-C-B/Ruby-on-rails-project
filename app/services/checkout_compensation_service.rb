class CheckoutCompensationService
  def initialize(purchase_reference, items_by_tenant)
    @purchase_reference = purchase_reference
    @items_by_tenant = items_by_tenant
  end

  def call
    @items_by_tenant.each_value do |items|
      tenant = items.first.listing_reference.tenant

      TenantDatabase.switch(tenant) do
        PurchaseHistory.transaction do
          purchases = PurchaseHistory
            .where(purchase_reference: @purchase_reference)
            .where(status: %w[pending successful])
            .lock

          purchases.each do |purchase|
            listing = ProductListing.lock.find(
              purchase.product_listing_id
            )

            listing.update!(
              stock_quantity: listing.stock_quantity + purchase.quantity
            )

            purchase.update!(status: "cancelled")
          end
        end
      end
    end
  end
end