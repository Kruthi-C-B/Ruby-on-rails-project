require "rails_helper"

RSpec.describe TenantDatabase do
  describe ".switch" do
    let(:tenant) do
      instance_double(
        Tenant,
        id: 42,
        apartment_tenant_name: "localfind_tenant_42",
        database_migrated_at?: true
      )
    end

    before do
      allow(described_class).to receive(:database_name_for).with(tenant)
        .and_return("test_localfind_tenant_42")
      allow(described_class).to receive(:verify_database_exists!).and_return(true)
      allow(described_class).to receive(:verify_ownership!).and_return(true)
      allow(described_class).to receive(:migration_marker_available?).and_return(true)
      allow(Apartment::Tenant).to receive(:switch).with("localfind_tenant_42").and_yield
    end

    it "switches only after verifying the database owner and migration marker" do
      expect(described_class.switch(tenant) { :switched }).to eq(:switched)
      expect(described_class).to have_received(:verify_ownership!)
        .with(tenant, "test_localfind_tenant_42")
      expect(Apartment::Tenant).to have_received(:switch).with("localfind_tenant_42")
    end

    it "refuses to switch when legacy migration is not complete" do
      allow(tenant).to receive(:database_migrated_at?).and_return(false)

      expect { described_class.switch(tenant) }.to raise_error(described_class::MigrationRequired)
      expect(Apartment::Tenant).not_to have_received(:switch)
    end
  end

  describe ".verify_ownership!" do
    let(:tenant) { instance_double(Tenant, id: 42) }
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before do
      allow(Apartment).to receive(:connection).and_return(connection)
      allow(connection).to receive(:select_values).with("SHOW DATABASES")
        .and_return([ "test_localfind_tenant_42" ])
      allow(connection).to receive(:quote_table_name) do |name|
        name.split(".").map { |part| "`#{part}`" }.join(".")
      end
    end

    it "accepts a database explicitly marked for the tenant" do
      allow(connection).to receive(:select_values)
        .with("SHOW TABLES FROM `test_localfind_tenant_42`")
        .and_return([ described_class::OWNERSHIP_TABLE ])
      allow(connection).to receive(:select_values)
        .with("SELECT tenant_id FROM `test_localfind_tenant_42`.`#{described_class::OWNERSHIP_TABLE}`")
        .and_return([ "42" ])

      expect(described_class.verify_ownership!(tenant, "test_localfind_tenant_42")).to be(true)
    end

    it "rejects a database owned by another tenant" do
      allow(connection).to receive(:select_values)
        .with("SHOW TABLES FROM `test_localfind_tenant_42`")
        .and_return([ described_class::OWNERSHIP_TABLE ])
      allow(connection).to receive(:select_values)
        .with("SELECT tenant_id FROM `test_localfind_tenant_42`.`#{described_class::OWNERSHIP_TABLE}`")
        .and_return([ "7" ])

      expect { described_class.verify_ownership!(tenant, "test_localfind_tenant_42") }
        .to raise_error(described_class::OwnershipError, /marked for tenant 7/)
    end

    it "rejects an existing database without an ownership marker" do
      allow(connection).to receive(:select_values)
        .with("SHOW TABLES FROM `test_localfind_tenant_42`").and_return([])

      expect { described_class.verify_ownership!(tenant, "test_localfind_tenant_42") }
        .to raise_error(described_class::OwnershipError, /no ownership marker/)
    end
  end

  describe ".provision!" do
    let(:tenant) do
      instance_double(
        Tenant,
        id: 42,
        database_migrated_at?: false,
        apartment_tenant_name: "localfind_tenant_42"
      )
    end
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before do
      allow(tenant).to receive(:with_lock) { |&block| block.call }
      allow(tenant).to receive(:reload).and_return(tenant)
      allow(tenant).to receive(:update_columns)
      allow(described_class).to receive(:database_name_for).with(tenant)
        .and_return("test_localfind_tenant_42")
      allow(described_class).to receive(:migration_marker_available?).and_return(true)
      allow(Apartment).to receive(:connection).and_return(connection)
      allow(connection).to receive(:select_values).with("SHOW DATABASES").and_return([])
      allow(Apartment::Tenant).to receive(:create).with("localfind_tenant_42").and_yield
      allow(described_class).to receive(:remove_shared_tables!)
      allow(described_class).to receive(:create_ownership_marker!)
    end

    it "creates a stable-name database and marks its ownership without copying legacy data" do
      allow(tenant).to receive(:update_columns)
      allow(described_class).to receive(:copy_legacy_data!)

      expect(described_class.provision!(tenant)).to eq(:created)
      expect(described_class).to have_received(:create_ownership_marker!).with(42)
      expect(described_class).not_to have_received(:copy_legacy_data!)
    end

    it "reuses a database only after owner verification and completed migration" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES")
        .and_return([ "test_localfind_tenant_42" ])
      allow(tenant).to receive(:database_migrated_at?).and_return(true)
      allow(described_class).to receive(:verify_ownership!).and_return(true)

      expect(described_class.provision!(tenant)).to eq(:existing)
      expect(described_class).to have_received(:verify_ownership!)
        .with(tenant, "test_localfind_tenant_42")
      expect(Apartment::Tenant).not_to have_received(:create)
    end

    it "rejects an existing unverified database instead of treating its name as ownership" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES")
        .and_return([ "test_localfind_tenant_42" ])
      allow(described_class).to receive(:verify_ownership!)
        .and_raise(described_class::OwnershipError, "owner unknown")

      expect { described_class.provision!(tenant) }
        .to raise_error(described_class::OwnershipError, "owner unknown")
      expect(tenant).not_to have_received(:update_columns)
    end

    it "does not mark an existing database migrated until explicitly verified" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES")
        .and_return([ "test_localfind_tenant_42" ])
      allow(described_class).to receive(:verify_ownership!).and_return(true)

      expect { described_class.provision!(tenant) }
        .to raise_error(described_class::MigrationRequired)
      expect(tenant).not_to have_received(:update_columns)
    end

    it "marks a newly created database complete only through new-tenant provisioning" do
      described_class.provision!(tenant)

      expect(tenant).to have_received(:update_columns).with(
        database_migrated_at: anything,
        database_migration_source: nil
      )
    end

    it "does not copy legacy data when normal provisioning reuses a verified database" do
      allow(connection).to receive(:select_values).with("SHOW DATABASES")
        .and_return([ "test_localfind_tenant_42" ])
      allow(tenant).to receive(:database_migrated_at?).and_return(true)
      allow(described_class).to receive(:verify_ownership!).and_return(true)
      allow(described_class).to receive(:copy_legacy_data!)

      expect(described_class.provision!(tenant)).to eq(:existing)
      expect(described_class).not_to have_received(:copy_legacy_data!)
    end
  end

  describe ".migrate_legacy_data!" do
    let(:tenant) do
      instance_double(
        Tenant,
        id: 42,
        slug: "oldstore",
        database_migrated_at?: false,
        database_migration_source: nil
      )
    end

    before do
      allow(tenant).to receive(:with_lock) { |&block| block.call }
      allow(tenant).to receive(:reload).and_return(tenant)
      allow(tenant).to receive(:update_columns)
      allow(described_class).to receive(:database_name_for).with(tenant)
        .and_return("test_localfind_tenant_42")
      allow(described_class).to receive(:legacy_database_name_for).with(tenant)
        .and_return("test_oldstore")
      allow(described_class).to receive(:verify_database_exists!).and_return(true)
      allow(described_class).to receive(:verify_ownership!).and_return(true)
      allow(described_class).to receive(:database_exists?).with("test_oldstore").and_return(true)
      allow(described_class).to receive(:database_exists?).with("test_localfind_tenant_42").and_return(true)
      allow(described_class).to receive(:migration_marker_available?).and_return(true)
    end

    it "copies then marks the tenant migrated" do
      allow(described_class).to receive(:copy_legacy_data!).and_return(true)

      described_class.migrate_legacy_data!(tenant)

      expect(described_class).to have_received(:copy_legacy_data!)
        .with(tenant, "test_oldstore", "test_localfind_tenant_42")
      expect(tenant).to have_received(:update_columns).with(
        database_migrated_at: anything,
        database_migration_source: "test_oldstore"
      )
    end

    it "does not mark migration complete if copying or verification fails" do
      allow(described_class).to receive(:copy_legacy_data!)
        .and_raise(described_class::MigrationRequired, "copy verification failed")

      expect { described_class.migrate_legacy_data!(tenant) }
        .to raise_error(described_class::MigrationRequired, "copy verification failed")
      expect(tenant).not_to have_received(:update_columns)
    end

    it "requires explicit confirmation when no legacy database exists" do
      allow(described_class).to receive(:database_exists?).with("test_oldstore").and_return(false)

      expect { described_class.migrate_legacy_data!(tenant) }
        .to raise_error(described_class::Error, /confirm there is no legacy data/)
      expect(tenant).not_to have_received(:update_columns)

      described_class.migrate_legacy_data!(tenant, no_legacy: true)
      expect(tenant).to have_received(:update_columns).with(
        database_migrated_at: anything,
        database_migration_source: nil
      )
    end

    it "requires explicit confirmation when the legacy name resolves to the stable database" do
      expect do
        described_class.migrate_legacy_data!(tenant, legacy_database: "test_localfind_tenant_42")
      end.to raise_error(described_class::Error, /use NO_LEGACY=1/)
      expect(tenant).not_to have_received(:update_columns)

      described_class.migrate_legacy_data!(
        tenant,
        legacy_database: "test_localfind_tenant_42",
        no_legacy: true
      )
      expect(tenant).to have_received(:update_columns).with(
        database_migrated_at: anything,
        database_migration_source: nil
      )
    end
  end

  describe ".copy_legacy_data!" do
    let(:tenant) { instance_double(Tenant, id: 42) }
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }
    let(:source_database) { "test_oldstore" }
    let(:target_database) { "test_localfind_tenant_42" }

    before do
      allow(described_class).to receive(:verify_ownership!).and_return(true)
      allow(Apartment).to receive(:connection).and_return(connection)
      allow(connection).to receive(:quote_table_name) do |name|
        name.split(".").map { |part| "`#{part}`" }.join(".")
      end
      allow(connection).to receive(:quote_column_name) { |name| "`#{name}`" }
      allow(connection).to receive(:select_values) do |sql|
        case sql
        when "SHOW TABLES FROM `#{source_database}`"
          %w[product_listings purchase_histories versions users]
        when "SHOW TABLES FROM `#{target_database}`"
          %w[product_listings purchase_histories versions]
        when /SHOW COLUMNS/
          table = sql.split(".").last.delete("`")
          {
            "product_listings" => %w[id product_id price],
            "purchase_histories" => %w[id product_listing_id total_price],
            "versions" => %w[id item_id item_type]
          }.fetch(table)
        else
          raise "Unexpected query: #{sql}"
        end
      end
      allow(connection).to receive(:select_all) do |sql|
        table = sql.split(".").last.split.first.delete("`")
        [ { "Column_name" => "id" } ]
      end
      allow(connection).to receive(:select_value).and_return("0")
      allow(connection).to receive(:execute)
      allow(connection).to receive(:transaction) { |&block| block.call }
    end

    it "copies tenant data idempotently and verifies every source row" do
      2.times do
        described_class.copy_legacy_data!(tenant, source_database, target_database)
      end

      expect(connection).to have_received(:execute).exactly(6).times
      expect(connection).to have_received(:select_value).exactly(6).times
    end

    it "rejects a conflicting or incomplete copy instead of marking it complete" do
      allow(connection).to receive(:select_value).and_return("1")

      expect do
        described_class.copy_legacy_data!(tenant, source_database, target_database)
      end.to raise_error(described_class::MigrationRequired, /not fully copied/)
    end

    it "fails before copying if a required table is missing" do
      allow(connection).to receive(:select_values)
        .with("SHOW TABLES FROM `#{source_database}`").and_return(%w[product_listings])
      allow(connection).to receive(:execute)

      expect do
        described_class.copy_legacy_data!(tenant, source_database, target_database)
      end.to raise_error(described_class::MigrationRequired, /purchase_histories/)
      expect(connection).not_to have_received(:execute)
    end
  end

  describe ".record_ownership!" do
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    it "rejects an ownership marker assigned to another tenant" do
      allow(connection).to receive(:select_values).and_return([ "7" ])
      allow(connection).to receive(:execute)

      expect do
        described_class.record_ownership!(42, "`tenant_db`.`#{described_class::OWNERSHIP_TABLE}`", connection)
      end.to raise_error(described_class::OwnershipError, /refusing to assign/)
      expect(connection).not_to have_received(:execute)
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

  describe "credential lifecycle and provisioning" do
    let(:tenant) do
      instance_double(
        Tenant,
        id: 7,
        db_username: "tenant_7_app",
        db_password: "secretpassword1234567890"
      )
    end
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before do
      allow(Apartment).to receive(:connection).and_return(connection)
      allow(connection).to receive(:raw_connection).and_return(nil)
      allow(connection).to receive(:execute)
    end

    it "creates MySQL user and grants scoped DML privileges on the tenant database" do
      described_class.provision_mysql_account!(tenant, "development_localfind_tenant_7", connection)

      expect(connection).to have_received(:execute).with(
        "CREATE USER IF NOT EXISTS 'tenant_7_app'@'%' IDENTIFIED BY 'secretpassword1234567890'"
      )
      expect(connection).to have_received(:execute).with(
        "ALTER USER 'tenant_7_app'@'%' IDENTIFIED BY 'secretpassword1234567890'"
      )
      expect(connection).to have_received(:execute).with(
        "REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'tenant_7_app'@'%'"
      )
      expect(connection).to have_received(:execute).with(
        "GRANT SELECT, INSERT, UPDATE, DELETE ON `development_localfind_tenant_7`.* TO 'tenant_7_app'@'%'"
      )
    end

    it "drops the MySQL user during deprovisioning" do
      described_class.deprovision_mysql_account!(tenant, connection)

      expect(connection).to have_received(:execute).with("DROP USER IF EXISTS 'tenant_7_app'@'%'")
    end

    it "rotates MySQL user password and updates the tenant record" do
      allow(tenant).to receive(:with_lock) { |&block| block.call }
      allow(tenant).to receive(:reload).and_return(tenant)
      allow(tenant).to receive(:rotate_db_password!)

      described_class.rotate_credentials!(tenant, "newrotatedpassword9999", connection)

      expect(connection).to have_received(:execute).with(
        "ALTER USER 'tenant_7_app'@'%' IDENTIFIED BY 'newrotatedpassword9999'"
      )
      expect(tenant).to have_received(:rotate_db_password!).with("newrotatedpassword9999")
    end
  end
end