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
      described_class.create!(user: owner, name: "First store", slug: "teststore")

      expect(described_class.new(slug: "teststore")).not_to be_valid
    end

    it "allows slugs containing only upper- and lowercase letters" do
      expect(described_class.new(slug: "StoreName", user: User.new)).to be_valid
    end

    it "rejects numbers, hyphens, and special characters in slugs" do
      [ "Store123", "store-name", "store_name", "store.name", "store name" ].each do |slug|
        tenant = described_class.new(slug: slug)

        expect(tenant).not_to be_valid, "expected #{slug.inspect} to be invalid"
        expect(tenant.errors[:slug]).not_to be_empty
      end
    end

    it "uses its persisted id for the database name independently of its slug" do
      owner = User.create!(email: "stable-tenant@example.test", password: "password123")
      tenant = described_class.create!(user: owner, name: "Store", slug: "firstslug")

      tenant.update!(slug: "secondslug")

      expect(tenant.apartment_tenant_name).to eq("localfind_tenant_#{tenant.id}")
      expect(tenant.slug).to eq("secondslug")
    end

    it "requires persistence before deriving a database name" do
      expect { described_class.new.apartment_tenant_name }
        .to raise_error(ArgumentError, /persisted/)
    end
  end
end
