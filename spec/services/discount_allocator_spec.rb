require "rails_helper"

RSpec.describe DiscountAllocator do
  subject(:allocations) { described_class.call(items, percentage) }

  def item(id, unit_price, quantity)
    instance_double(CartItem, id: id, unit_price: BigDecimal(unit_price), quantity: quantity)
  end

  describe ".call" do
    context "with a discount" do
      let(:items) do
        [ item(11, "10.00", 1), item(12, "20.00", 1), item(13, "30.00", 1) ]
      end
      let(:percentage) { 10 }

      it "allocates the largest remainders to produce exact cent totals" do
        expect(allocations).to eq(
          11 => { discount_amount: BigDecimal("1.00"), total_price: BigDecimal("9.00") },
          12 => { discount_amount: BigDecimal("2.00"), total_price: BigDecimal("18.00") },
          13 => { discount_amount: BigDecimal("3.00"), total_price: BigDecimal("27.00") }
        )
      end
    end

    it "distributes leftover cents deterministically by item id" do
      items = [ item(20, "0.10", 1), item(10, "0.10", 1) ]

      expect(described_class.call(items, 50)).to eq(
        20 => { discount_amount: BigDecimal("0.05"), total_price: BigDecimal("0.05") },
        10 => { discount_amount: BigDecimal("0.05"), total_price: BigDecimal("0.05") }
      )
    end

    it "uses line cents rather than allocating from rounded line totals" do
      items = [ item(1, "0.10", 1), item(2, "0.20", 1), item(3, "0.30", 1) ]

      allocations = described_class.call(items, 10)
      expect(allocations.values.sum { |amount| amount[:discount_amount] }).to eq(BigDecimal("0.06"))
      expect(allocations.values.sum { |amount| amount[:total_price] }).to eq(BigDecimal("0.54"))
    end

    it "returns zero discounts for a zero subtotal" do
      items = [ item(1, "0.00", 2) ]

      expect(described_class.call(items, 50)).to eq(
        1 => { discount_amount: BigDecimal("0.00"), total_price: BigDecimal("0.00") }
      )
    end

    it "preserves an empty allocation" do
      expect(described_class.call([], 20)).to eq({})
    end
  end
end
