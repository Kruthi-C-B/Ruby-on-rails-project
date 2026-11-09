class AddDatabaseMigrationSourceToTenants < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:tenants)

    add_column :tenants, :database_migration_source, :string unless column_exists?(:tenants, :database_migration_source)
  end
end
