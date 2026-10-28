class CheckoutService
  class CheckoutError < StandardError; end

  def initialize(cart)
    @cart = cart
  end

  def call
    @cart.with_lock do
      items = @cart.cart_items.includes(listing_reference: :tenant).to_a
      raise CheckoutError, "Cart is empty." if items.empty?
      raise CheckoutError, "This cart has already been checked out." unless @cart.status == "pending"

      @cart.update!(purchase_reference: SecureRandom.uuid) if @cart.purchase_reference.blank?
      purchase_reference = @cart.purchase_reference
      items_by_tenant = items.group_by { |item| item.listing_reference.tenant_id }
      amounts_by_item = DiscountAllocator.call(items, @cart.discount&.percentage || 0)

      validate_stock!(items_by_tenant, purchase_reference, amounts_by_item)
      create_pending_purchases!(items_by_tenant, purchase_reference, amounts_by_item)
      complete_purchases!(items_by_tenant, purchase_reference)
      @cart.update!(status: "ordered")

      purchase_reference
    end
  end

  private

  def validate_stock!(items_by_tenant, purchase_reference, amounts_by_item)
    items_by_tenant.each_value do |items|
      tenant = items.first.listing_reference.tenant
      TenantDatabase.switch(tenant) do
        items.each do |item|
          listing_id = item.listing_reference.tenant_listing_id
          existing = PurchaseHistory.find_by(
            purchase_reference: purchase_reference,
            product_listing_id: listing_id
          )
          if existing
            amounts = amounts_by_item.fetch(item.id)
            unless existing.quantity == item.quantity &&
                   existing.discount_amount == amounts[:discount_amount] &&
                   existing.total_price == amounts[:total_price]
              raise CheckoutError, "The cart changed while checkout was being retried."
            end
            next
          end

          listing = ProductListing.find_by(id: listing_id)
          raise CheckoutError, "A product is no longer available." unless listing
          if listing.stock_quantity < item.quantity
            raise CheckoutError, "A product does not have enough stock."
          end
        end
      end
    end
  end

  def create_pending_purchases!(items_by_tenant, purchase_reference, amounts_by_item)
    items_by_tenant.each_value do |items|
      tenant = items.first.listing_reference.tenant
      TenantDatabase.switch(tenant) do
        ActiveRecord::Base.transaction do
          items.each do |item|
            listing_id = item.listing_reference.tenant_listing_id
            next if PurchaseHistory.exists?(
              purchase_reference: purchase_reference,
              product_listing_id: listing_id
            )

            listing = ProductListing.lock.find(listing_id)
            if listing.stock_quantity < item.quantity
              raise CheckoutError, "A product does not have enough stock."
            end

            amounts = amounts_by_item.fetch(item.id)
            listing.update!(stock_quantity: listing.stock_quantity - item.quantity)
            PurchaseHistory.create!(
              user_id: @cart.user_id,
              product_listing_id: listing.id,
              product_id: listing.product_id,
              quantity: item.quantity,
              unit_price: item.unit_price,
              discount_amount: amounts[:discount_amount],
              total_price: amounts[:total_price],
              purchase_reference: purchase_reference,
              status: "pending"
            )
          end
        end

        items.each do |item|
          listing = ProductListing.find(item.listing_reference.tenant_listing_id)
          item.listing_reference.update!(stock_quantity: listing.stock_quantity)
        end
      end
    end
  end

  def complete_purchases!(items_by_tenant, purchase_reference)
    items_by_tenant.each_value do |items|
      tenant = items.first.listing_reference.tenant
      TenantDatabase.switch(tenant) do
        PurchaseHistory.where(
          purchase_reference: purchase_reference,
          status: "pending"
        ).find_each do |purchase|
          purchase.update!(status: "successful", purchased_at: Time.current)
        end
      end
    end
  end
end
