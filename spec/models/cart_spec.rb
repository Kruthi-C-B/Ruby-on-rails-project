require "rails_helper"

RSpec.describe Cart do
  describe "associations" do
    it "has the expected optional and through associations" do
      expect(described_class.reflect_on_association(:user).options[:optional]).to be(true)
      expect(described_class.reflect_on_association(:discount).options[:optional]).to be(true)
      expect(described_class.reflect_on_association(:cart_items).macro).to eq(:has_many)
      expect(described_class.reflect_on_association(:listing_references).options[:through]).to eq(:cart_items)
    end
  end

  describe "#subtotal" do
    it "sums quantity times unit price and rounds to two decimal places" do
      cart = described_class.new
      item = instance_double(CartItem, unit_price: BigDecimal("10.005"), quantity: 2)
      allow(cart).to receive(:cart_items).and_return([ item ])

      expect(cart.subtotal).to eq(BigDecimal("20.01"))
    end

    it "is zero for an empty cart" do
      expect(described_class.new.subtotal).to eq(BigDecimal("0.00"))
    end
  end

  describe "discount calculations" do
    it "returns zero discount and unchanged total without a discount" do
      cart = described_class.new
      allow(cart).to receive(:subtotal).and_return(BigDecimal("12.345"))

      expect(cart.discount_amount).to eq(BigDecimal("0.00"))
      expect(cart.total_price).to eq(BigDecimal("12.35"))
    end

    it "applies and rounds a percentage discount" do
      cart = described_class.new(discount: Discount.new(percentage: 20))
      allow(cart).to receive(:subtotal).and_return(BigDecimal("20.91"))

      expect(cart.discount_amount).to eq(BigDecimal("4.18"))
      expect(cart.total_price).to eq(BigDecimal("16.73"))
    end
  end
end
