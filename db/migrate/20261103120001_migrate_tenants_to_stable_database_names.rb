class MigrateTenantsToStableDatabaseNames < ActiveRecord::Migration[8.1]
  def up
    # Tenant databases are migrated only by the explicit ownership-verified task.
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Tenant database migration is performed by an explicit, non-destructive task"
  end
end
