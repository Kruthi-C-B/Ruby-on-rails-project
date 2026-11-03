require "rails_helper"

RSpec.describe ListingService do
  let(:tenant) { instance_double(Tenant) }
  let(:listing) { instance_double(ProductListing, id: 12) }

  before do
    allow(TenantDatabase).to receive(:switch) do |_tenant, &block|
      block.call
    end
  end

  describe "#update" do
    it "updates the tenant listing and synchronizes its shared reference" do
      reference = instance_double(ListingReference)
      allow(ProductListing).to receive(:find).with("12").and_return(listing)
      allow(listing).to receive(:update).with(price: "15.00").and_return(true)
      allow(ListingReference).to receive(:find_by!)
        .with(tenant: tenant, tenant_listing_id: listing.id)
        .and_return(reference)
      allow(reference).to receive(:sync_from_listing!).with(listing)

      result = described_class.new(tenant).update(id: "12", attributes: { price: "15.00" })

      expect(result.listing).to eq(listing)
      expect(result.errors).to be_empty
      expect(reference).to have_received(:sync_from_listing!).with(listing)
    end

    it "returns validation messages without synchronizing the shared reference" do
      errors = instance_double(ActiveModel::Errors, full_messages: [ "Price must be greater than or equal to 0" ])
      allow(ProductListing).to receive(:find).with("12").and_return(listing)
      allow(listing).to receive(:update).with(price: "-1").and_return(false)
      allow(listing).to receive(:errors).and_return(errors)
      expect(ListingReference).not_to receive(:find_by!)

      result = described_class.new(tenant).update(id: "12", attributes: { price: "-1" })

      expect(result.listing).to be_nil
      expect(result.errors).to eq([ "Price must be greater than or equal to 0" ])
    end
  end
end
