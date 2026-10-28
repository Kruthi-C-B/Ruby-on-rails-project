class DiscountAllocator
  def self.call(items, percentage)
    line_subtotals = items.to_h do |item|
      line_total = (BigDecimal(item.unit_price.to_s) * item.quantity * 100).round.to_i
      [ item.id, line_total ]
    end
    subtotal_cents = line_subtotals.values.sum
    return line_subtotals.transform_values { |cents| amount_from_cents(cents, 0) } if subtotal_cents.zero?

    discount_cents = (BigDecimal(subtotal_cents.to_s) * BigDecimal(percentage.to_s) / 100).round.to_i
    allocations = line_subtotals.map do |item_id, line_cents|
      numerator = discount_cents * line_cents
      [ item_id, numerator / subtotal_cents, numerator % subtotal_cents ]
    end
    remaining_cents = discount_cents - allocations.sum { |_id, base, _remainder| base }
    allocations.sort_by { |item_id, _base, remainder| [ -remainder, item_id ] }
      .first(remaining_cents)
      .each { |allocation| allocation[1] += 1 }
    discounts_by_item = allocations.to_h { |item_id, discount, _remainder| [ item_id, discount ] }

    line_subtotals.to_h do |item_id, line_cents|
      discount = discounts_by_item.fetch(item_id)
      [ item_id, amount_from_cents(line_cents, discount) ]
    end
  end

  def self.amount_from_cents(subtotal_cents, discount_cents)
    {
      discount_amount: BigDecimal(discount_cents.to_s) / 100,
      total_price: BigDecimal((subtotal_cents - discount_cents).to_s) / 100
    }
  end
  private_class_method :amount_from_cents
end
