require "rails_helper"

RSpec.describe Tenant do
  describe "associations" do
    it "belongs to a user and has dependent listing references" do
      expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:listing_references).options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires a slug" do
      tenant = described_class.new

      expect(tenant).not_to be_valid
      expect(tenant.errors[:slug]).to include("can't be blank")
    end

    it "requires a unique slug" do
      owner = User.create!(email: "tenant-owner@example.test", password: "password123")
      described_class.create!(user: owner, name: "First store", slug: "test-store")

      expect(described_class.new(slug: "test-store")).not_to be_valid
    end

    it "allows alphanumeric characters and hyphens" do
      expect(described_class.new(slug: "Store-123", user: User.new)).to be_valid
    end

    it "rejects slugs containing other characters" do
      tenant = described_class.new(slug: "bad store")

      expect(tenant).not_to be_valid
      expect(tenant.errors[:slug]).not_to be_empty
    end
  end
end
