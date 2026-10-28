require "rails_helper"

RSpec.describe Category do
  describe "associations" do
    it "has many products" do
      expect(described_class.reflect_on_association(:products).macro).to eq(:has_many)
    end
  end

  describe "validations" do
    it "requires a name" do
      category = described_class.new

      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it "requires a case-insensitively unique name" do
      described_class.create!(name: "Books")

      expect(described_class.new(name: "books")).not_to be_valid
    end
  end
end
