class RemoveSharedTablesFromTenantDatabases < ActiveRecord::Migration[8.1]
  def up
    unless Apartment::Tenant.current == Apartment::Tenant.default_tenant
      TenantDatabase.remove_shared_tables!
      return
    end

    Tenant.find_each do |tenant|
      TenantDatabase.switch(tenant) do
        TenantDatabase.remove_shared_tables!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Shared tables in tenant databases are recreated when a tenant database is provisioned"
  end
end
