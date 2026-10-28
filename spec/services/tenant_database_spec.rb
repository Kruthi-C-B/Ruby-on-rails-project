require "rails_helper"

RSpec.describe TenantDatabase do
  describe ".switch" do
    it "switches Apartment to the tenant slug and returns the block value" do
      tenant = instance_double(Tenant, slug: "switch-store")
      allow(Apartment::Tenant).to receive(:switch).with("switch-store").and_yield

      expect(described_class.switch(tenant) { :switched }).to eq(:switched)
    end
  end

  describe ".provision!" do
    let(:tenant) { instance_double(Tenant, slug: "new-store") }
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before do
      allow(Apartment::Tenant).to receive(:environmentify).with("new-store").and_return("local_find_new_store")
      allow(Apartment).to receive(:connection).and_return(connection)
    end

    it "refuses to overwrite an existing tenant database" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES").and_return([ "local_find_new_store" ])

      expect { described_class.provision!(tenant) }
        .to raise_error(Apartment::TenantExists, /local_find_new_store/)
    end

    it "creates a tenant database and removes shared tables" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES").and_return([])
      allow(Apartment::Tenant).to receive(:create).with("new-store").and_yield
      allow(described_class).to receive(:remove_shared_tables!)

      described_class.provision!(tenant)

      expect(described_class).to have_received(:remove_shared_tables!).once
    end

    it "drops a newly created database when provisioning fails" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES").and_return([], [ "local_find_new_store" ])
      allow(Apartment::Tenant).to receive(:create).with("new-store").and_raise("migration failed")
      allow(Apartment::Tenant).to receive(:drop)

      expect { described_class.provision!(tenant) }.to raise_error(RuntimeError, "migration failed")
      expect(Apartment::Tenant).to have_received(:drop).with("new-store")
    end
  end

  describe ".remove_shared_tables!" do
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
      allow(connection).to receive(:quote_table_name) { |table| "`#{table}`" }
    end

    it "raises before dropping any table when tenant copies contain data" do
      allow(connection).to receive(:data_source_exists?).and_return(true)
      allow(connection).to receive(:select_value) do |sql|
        sql.include?("users") ? "1" : "0"
      end
      allow(connection).to receive(:drop_table)

      expect { described_class.remove_shared_tables! }
        .to raise_error(described_class::SharedTableDataError, /users \(1 rows\)/)
      expect(connection).not_to have_received(:drop_table)
    end

    it "drops existing empty shared tables" do
      allow(connection).to receive(:data_source_exists?) { |table| table == "users" || table == "carts" }
      allow(connection).to receive(:select_value).and_return("0")
      allow(connection).to receive(:drop_table)

      described_class.remove_shared_tables!

      expect(connection).to have_received(:drop_table).with("users")
      expect(connection).to have_received(:drop_table).with("carts")
    end
  end
end
