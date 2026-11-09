namespace :tenant_databases do
  desc "List tenant slugs that do not contain only ASCII letters"
  task check_slugs: :environment do
    invalid_tenants = Tenant.find_each.filter_map do |tenant|
      [ tenant.id, tenant.slug ] unless tenant.slug.match?(/\A[a-zA-Z]+\z/)
    end

    if invalid_tenants.empty?
      puts "All tenant slugs contain only ASCII letters."
    else
      puts "Tenant slugs requiring review:"
      invalid_tenants.each { |id, slug| puts "  tenant #{id}: #{slug.inspect}" }
      abort "Update these slugs manually before enforcing the new validation."
    end
  end

  desc "Explicitly attest that a database belongs to a tenant; does not copy data"
  task adopt: :environment do
    tenant_id = ENV.fetch("TENANT_ID") { abort "Set TENANT_ID" }.to_i
    database_name = ENV.fetch("DATABASE") { abort "Set DATABASE to the exact MySQL database name" }
    confirmation = ENV.fetch("CONFIRM_TENANT_ID") { abort "Set CONFIRM_TENANT_ID to acknowledge ownership" }.to_i
    abort "CONFIRM_TENANT_ID must equal TENANT_ID" unless confirmation == tenant_id

    tenant = Tenant.find(tenant_id)
    TenantDatabase.adopt_ownership!(tenant, database_name: database_name)
    puts "Recorded tenant #{tenant.id} as the owner of #{database_name}. No application data was changed."
  end

  desc "Copy and verify legacy tenant data for one tenant or all tenants"
  task migrate: :environment do
    tenant_id = ENV["TENANT_ID"]
    if ENV["LEGACY_DATABASE"].present? && tenant_id.blank?
      abort "Set TENANT_ID when specifying LEGACY_DATABASE."
    end

    tenants = tenant_id.present? ? [ Tenant.find(tenant_id) ] : Tenant.order(:id)
    no_legacy = ENV["NO_LEGACY"] == "1"
    tenants.each do |tenant|
      TenantDatabase.migrate_legacy_data!(
        tenant,
        legacy_database: ENV["LEGACY_DATABASE"].presence,
        no_legacy: no_legacy
      )
      puts "Tenant #{tenant.id} data is copied and verified."
    end
  end

  desc "Verify ownership markers and migration status for all tenants"
  task verify: :environment do
    Tenant.order(:id).each do |tenant|
      TenantDatabase.verify_migration!(tenant)
      puts "Tenant #{tenant.id}: verified."
    end
  end

  desc "Ensure all tenants have dedicated MySQL users and scoped DML credentials"
  task provision_credentials: :environment do
    Tenant.find_each do |tenant|
      tenant.ensure_db_credentials!
      db_name = TenantDatabase.database_name_for(tenant)
      if TenantDatabase.database_exists?(db_name)
        TenantDatabase.provision_mysql_account!(tenant, db_name)
        puts "Provisioned isolated credentials for Tenant #{tenant.id} (#{tenant.db_username}) on #{db_name}"
      else
        puts "Skipping Tenant #{tenant.id}: Database #{db_name} does not exist yet."
      end
    end
  end

  desc "Rotate MySQL database credentials for a specific tenant"
  task rotate_credential: :environment do
    tenant_id = ENV.fetch("TENANT_ID") { abort "Set TENANT_ID" }.to_i
    tenant = Tenant.find(tenant_id)
    new_password = ENV["NEW_PASSWORD"].presence || SecureRandom.base58(32)
    TenantDatabase.rotate_credentials!(tenant, new_password)
    puts "Successfully rotated database credentials for Tenant #{tenant.id} (#{tenant.db_username})."
  end

  desc "Revoke master wildcard tenant access from main application user"
  task revoke_master_key: :environment do
    username = ENV.fetch("LOCALFIND_MAIN_DB_USERNAME", "localfind_main")
    env_name = Rails.env
    tenant_prefix = env_name == "test" ? "test_" : "#{env_name}_"
    tenant_pattern = "#{tenant_prefix}localfind\\_tenant\\_%"

    stmts = LocalFindShared::DatabaseAccess.revoke_tenant_pattern_statements(
      account: username,
      tenant_database_pattern: tenant_pattern
    )
    connection = Apartment.connection
    stmts.each do |stmt|
      connection.execute(stmt) rescue nil
      puts "Executed: #{stmt}"
    end
    puts "Revoked master wildcard tenant permissions from #{username}."
  end

  desc "Purge all existing tenants, drop their MySQL databases and users cleanly"
  task purge_all: :environment do
    CartItem.delete_all
    ListingReference.delete_all

    connection = Apartment.connection
    all_dbs = connection.select_values("SHOW DATABASES")

    Tenant.find_each do |tenant|
      tenant_dbs = [
        TenantDatabase.database_name_for(tenant),
        "development_#{tenant.slug}",
        "test_#{tenant.slug}"
      ].uniq

      tenant_dbs.each do |db_name|
        if all_dbs.include?(db_name)
          connection.execute("DROP DATABASE IF EXISTS `#{db_name}`")
          puts "Dropped database #{db_name}"
        end
      end

      TenantDatabase.deprovision_mysql_account!(tenant)
      tenant.destroy!
      puts "Deleted Tenant record #{tenant.id} (#{tenant.name})"
    end

    # Clean up any leftover databases matching tenant naming patterns
    all_dbs = connection.select_values("SHOW DATABASES")
    all_dbs.grep(/localfind_tenant_|_-store|_store/).each do |db|
      next if db == "local_find_development" || db == "local_find_test" || db == "local_find_production"
      connection.execute("DROP DATABASE IF EXISTS `#{db}`")
      puts "Dropped leftover database #{db}"
    end

    # Drop any leftover tenant MySQL users
    users = connection.select_values("SELECT user FROM mysql.user WHERE user LIKE 'tenant_%_app' OR user LIKE 'store_%'")
    users.each do |u|
      connection.execute("DROP USER IF EXISTS '#{u}'@'%'")
      puts "Dropped MySQL user #{u}"
    end

    puts "All old tenants, their databases, and MySQL users have been purged successfully."
  end
end
