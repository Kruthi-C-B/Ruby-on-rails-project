class AddDatabaseMigratedAtToTenants < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:tenants)

    add_column :tenants, :database_migrated_at, :datetime unless column_exists?(:tenants, :database_migrated_at)
  end
end
