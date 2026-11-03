class AddDatabaseMigrationSourceToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :database_migration_source, :string
  end
end
