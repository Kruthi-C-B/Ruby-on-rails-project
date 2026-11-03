require "rails_helper"

RSpec.describe Tenant, type: :model do
  it "uses the persisted tenant id rather than the mutable slug" do
    tenant = Tenant.new(id: 42, slug: "RenamedStore")
    allow(tenant).to receive(:persisted?).and_return(true)

    expect(tenant.apartment_tenant_name).to eq("localfind_tenant_42")
  end

  it "does not name a database for an unpersisted tenant" do
    tenant = Tenant.new(slug: "NewStore")

    expect { tenant.apartment_tenant_name }.to raise_error(ArgumentError, /persisted/)
  end
end
