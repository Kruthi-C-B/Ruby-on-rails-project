require "rails_helper"

RSpec.describe CartItem do
  describe "associations" do
    it "belongs to a cart and listing reference" do
      expect(described_class.reflect_on_association(:cart).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:listing_reference).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a positive integer quantity" do
      expect(described_class.new(quantity: 0)).not_to be_valid
      expect(described_class.new(quantity: 1.5)).not_to be_valid
    end

    it "accepts a positive integer quantity" do
      item = described_class.new(
        quantity: 2,
        cart: Cart.new,
        listing_reference: ListingReference.new
      )

      expect(item).to be_valid
    end
  end
end
