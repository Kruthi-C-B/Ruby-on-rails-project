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

    it "allows lowercase letters and numbers separated by single hyphens" do
      expect(described_class.new(slug: "store123-name", user: User.new)).to be_valid
    end

    it "rejects uppercase letters, repeated or leading hyphens, and special characters in slugs" do
      [ "Store123", "-store", "store-", "store--name", "store_name", "store.name", "store name" ].each do |slug|
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

  describe "database credentials" do
    let(:owner) { User.create!(email: "cred-owner@example.test", password: "password123") }
    let(:tenant) { described_class.create!(user: owner, name: "CredStore", slug: "credstore") }

    it "derives default database username from the tenant id" do
      expect(tenant.default_db_username).to eq("tenant_#{tenant.id}_app")
    end

    it "generates and encrypts database credentials upon demand" do
      expect(tenant.db_username).to be_nil
      expect(tenant.db_password).to be_nil

      tenant.ensure_db_credentials!
      tenant.reload

      expect(tenant.db_username).to eq("tenant_#{tenant.id}_app")
      expect(tenant.db_password).to be_present
      expect(tenant.db_password.length).to be >= 32
    end

    it "allows rotating database passwords without affecting username" do
      tenant.ensure_db_credentials!
      original_username = tenant.db_username
      original_password = tenant.db_password

      tenant.rotate_db_password!("newsecretpassword12345678901234")
      tenant.reload

      expect(tenant.db_username).to eq(original_username)
      expect(tenant.db_password).to eq("newsecretpassword12345678901234")
      expect(tenant.db_password).not_to eq(original_password)
    end
  end
end
