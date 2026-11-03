class AddDatabaseMigratedAtToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :database_migrated_at, :datetime
  end
end
