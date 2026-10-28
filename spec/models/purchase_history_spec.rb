require "rails_helper"

RSpec.describe PurchaseHistory do
  describe "associations" do
    it "belongs to a product listing and product" do
      expect(described_class.reflect_on_association(:product_listing).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:product).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires positive integer quantity" do
      purchase = described_class.new(quantity: 0)

      expect(purchase).not_to be_valid
      expect(purchase.errors[:quantity]).not_to be_empty
    end

    it "requires non-negative unit and total prices" do
      purchase = described_class.new(unit_price: -1, total_price: -1)

      expect(purchase).not_to be_valid
      expect(purchase.errors[:unit_price]).not_to be_empty
      expect(purchase.errors[:total_price]).not_to be_empty
    end

    it "requires purchase reference and status" do
      purchase = described_class.new(purchase_reference: nil, status: nil)

      expect(purchase).not_to be_valid
      expect(purchase.errors[:purchase_reference]).to include("can't be blank")
      expect(purchase.errors[:status]).to include("can't be blank")
    end
  end
end
