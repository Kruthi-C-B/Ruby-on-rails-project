class BackfillDiscountedPurchaseTotals < ActiveRecord::Migration[8.1]
  def up
    return unless Apartment::Tenant.current == Apartment::Tenant.default_tenant

    Cart.where(status: "ordered")
      .where.not(purchase_reference: nil)
      .where.not(discount_id: nil)
      .includes(:discount, cart_items: { listing_reference: :tenant })
      .find_each do |cart|
        items = cart.cart_items.to_a
        allocations = DiscountAllocator.call(items, cart.discount.percentage)

        items.each do |item|
          reference = item.listing_reference
          amount = allocations.fetch(item.id)
          TenantDatabase.switch(reference.tenant) do
            purchase = PurchaseHistory.find_by(
              purchase_reference: cart.purchase_reference,
              product_listing_id: reference.tenant_listing_id
            )
            next unless purchase
            next if purchase.discount_amount.positive?

            purchase.update!(
              discount_amount: amount[:discount_amount],
              total_price: amount[:total_price]
            )
          end
        end
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Discounted purchase totals are historical payment records and cannot be safely reversed"
  end
end
