require "rails_helper"

RSpec.describe ListingReference do
  describe "associations" do
    it "has the configured tenant, product, and restricted cart item associations" do
      expect(described_class.reflect_on_association(:tenant).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:product).macro).to eq(:belongs_to)

      cart_items = described_class.reflect_on_association(:cart_items)
      expect(cart_items.macro).to eq(:has_many)
      expect(cart_items.options[:dependent]).to eq(:restrict_with_exception)
    end
  end

  describe "validations" do
    subject(:reference) do
      described_class.new(
        tenant: Tenant.new,
        product: Product.new,
        tenant_listing_id: 12,
        price: 10,
        stock_quantity: 3
      )
    end

    it "requires tenant-local listing and product identifiers to be unique" do
      owner = User.create!(email: "reference-owner@example.test", password: "password123")
      tenant = Tenant.create!(user: owner, name: "Reference store", slug: "reference-store")
      category = Category.create!(name: "Reference category")
      product = Product.create!(category: category, name: "Reference product")
      described_class.create!(tenant: tenant, product: product, tenant_listing_id: 12, price: 10, stock_quantity: 3)

      expect(described_class.new(tenant: tenant, product: product, tenant_listing_id: 12, price: 10, stock_quantity: 3)).not_to be_valid
    end

    it "requires non-negative price and non-negative integer stock" do
      reference.price = -1
      reference.stock_quantity = 1.5

      expect(reference).not_to be_valid
      expect(reference.errors[:price]).not_to be_empty
      expect(reference.errors[:stock_quantity]).not_to be_empty
    end
  end

  describe "#sync_from_listing!" do
    it "updates tenant listing fields from a listing" do
      reference = described_class.new
      listing = ProductListing.new(id: 99, product_id: 7, price: 42.50, stock_quantity: 4)
      allow(reference).to receive(:update!).with(
        tenant_listing_id: 99,
        product_id: 7,
        price: listing.price,
        stock_quantity: 4
      ).and_return(true)

      expect(reference.sync_from_listing!(listing)).to eq(true)
    end
  end

  describe "#product_listing" do
    it "switches to the tenant and finds the tenant-local listing" do
      tenant = Tenant.new(slug: "listing-product-store")
      reference = described_class.new(tenant: tenant, tenant_listing_id: 14)
      listing = instance_double(ProductListing)
      allow(TenantDatabase).to receive(:switch).with(tenant).and_yield
      allow(ProductListing).to receive(:find_by!).with(id: 14).and_return(listing)

      expect(reference.product_listing).to eq(listing)
    end
  end
end
