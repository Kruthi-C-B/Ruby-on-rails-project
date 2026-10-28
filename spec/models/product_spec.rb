require "rails_helper"

RSpec.describe Product do
  describe "associations" do
    it "belongs to a category and exposes listing references" do
      expect(described_class.reflect_on_association(:category).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:listing_references).macro).to eq(:has_many)
    end
  end
end
