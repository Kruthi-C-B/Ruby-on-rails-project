class ClearUnverifiedTenantDatabaseMarkers < ActiveRecord::Migration[8.1]
  def up
    Tenant.where.not(database_migrated_at: nil).update_all(database_migrated_at: nil)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Database markers set before ownership verification cannot be restored safely"
  end
end
