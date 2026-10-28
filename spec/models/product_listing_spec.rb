require "rails_helper"

RSpec.describe ProductListing do
  describe "associations" do
    it "belongs to a product" do
      expect(described_class.reflect_on_association(:product).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires non-negative price" do
      expect(described_class.new(price: -0.01)).not_to be_valid
      expect(described_class.new(price: nil)).not_to be_valid
    end

    it "requires non-negative integer stock" do
      expect(described_class.new(stock_quantity: -1)).not_to be_valid
      expect(described_class.new(stock_quantity: 1.5)).not_to be_valid
      expect(described_class.new(stock_quantity: nil)).not_to be_valid
    end

    it "rejects a second listing for the same product" do
      category = Category.create!(name: "Listing product category")
      product = Product.create!(category: category, name: "Only product")
      described_class.create!(product: product, price: 10, stock_quantity: 5)

      duplicate = described_class.new(product: product, price: 12, stock_quantity: 2)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_id]).to include("is already listed in your store. Please edit the existing listing instead.")
    end
  end
end
