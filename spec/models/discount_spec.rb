require "rails_helper"

RSpec.describe Discount do
  describe "associations" do
    it "has many carts" do
      expect(described_class.reflect_on_association(:carts).macro).to eq(:has_many)
    end
  end

  describe "validations" do
    it "requires a code" do
      expect(described_class.new(percentage: 10)).not_to be_valid
    end

    it "requires a case-insensitively unique code" do
      described_class.create!(code: "SAVE", percentage: 10)

      expect(described_class.new(code: "save", percentage: 20)).not_to be_valid
    end

    it "requires a percentage greater than zero and no more than 100" do
      expect(described_class.new(code: "ZERO", percentage: 0)).not_to be_valid
      expect(described_class.new(code: "HIGH", percentage: 100.01)).not_to be_valid
      expect(described_class.new(code: "VALID", percentage: 100)).to be_valid
    end
  end
end
