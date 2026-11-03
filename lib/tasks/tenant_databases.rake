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
end
