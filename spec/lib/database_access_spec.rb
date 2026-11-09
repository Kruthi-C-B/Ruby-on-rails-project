require "rails_helper"

RSpec.describe LocalFindShared::DatabaseAccess do
  it "limits admin-dashboard to shared data it reads or owns and no tenant databases" do
    grants = described_class.statements(
      service: :admin_dashboard,
      database: "local_find_development",
      account: "localfind_admin_dashboard"
    )

    expect(grants).to include(
      "GRANT SELECT (`id`, `email`, `is_admin`, `platform_admin`, `created_at`) ON `local_find_development`.`users` TO 'localfind_admin_dashboard'@'%'"
    )
    expect(grants.none? { |grant| grant.include?("_tenant_") }).to be(true)
    expect(grants).not_to include(a_string_matching(/password_digest/))
    expect(grants.none? { |grant| grant.include?("ON *.*") }).to be(true)
  end

  it "limits security-logs to reading the login audit fields" do
    grants = described_class.statements(
      service: :security_logs,
      database: "local_find_development",
      account: "localfind_security_logs"
    )

    expect(grants).to include(
      "GRANT SELECT (`id`, `email`, `ip_address`, `status`, `failure_reason`, `created_at`, `user_id`) ON `local_find_development`.`login_audits` TO 'localfind_security_logs'@'%'"
    )
    expect(grants).not_to include(a_string_matching(/users|tenants|categories/))
    expect(grants).not_to include(a_string_matching(/INSERT|UPDATE|DELETE/))
  end

  it "gives the main app catalog reads and its tenant-database provisioning privileges in legacy mode" do
    grants = described_class.statements(
      service: :main,
      database: "local_find_development",
      account: "localfind_main",
      tenant_database_pattern: "development\\_localfind\\_tenant\\_%"
    )

    expect(grants).to include("GRANT SELECT ON `local_find_development`.`products` TO 'localfind_main'@'%'")
    expect(grants).to include("GRANT CREATE ON *.* TO 'localfind_main'@'%'")
    expect(grants).to include(
      "GRANT ALL PRIVILEGES ON `development\\_localfind\\_tenant\\_%`.* TO 'localfind_main'@'%'"
    )
    expect(grants).not_to include(a_string_matching(/categories` TO 'localfind_main'@'%'.*(INSERT|UPDATE|DELETE)/))
  end

  it "locks down main app privileges in isolated mode without DDL or tenant wildcard grants" do
    grants = described_class.statements(
      service: :main,
      database: "local_find_development",
      account: "localfind_main",
      tenant_database_pattern: "development\\_localfind\\_tenant\\_%",
      isolated_app: true
    )

    expect(grants).to include("GRANT SELECT ON `local_find_development`.`products` TO 'localfind_main'@'%'")
    expect(grants).not_to include("GRANT CREATE ON *.* TO 'localfind_main'@'%'")
    expect(grants.none? { |grant| grant.include?("ALL PRIVILEGES") }).to be(true)
  end

  it "generates scoped DML privileges for dedicated tenant application accounts" do
    grants = described_class.tenant_application_statements(
      database: "development_localfind_tenant_42",
      account: "tenant_42_app"
    )

    expect(grants).to eq([
      "GRANT SELECT, INSERT, UPDATE, DELETE ON `development_localfind_tenant_42`.* TO 'tenant_42_app'@'%'"
    ])
    expect(grants).not_to include(a_string_matching(/CREATE|ALTER|DROP/))
  end

  it "generates migration privileges for dedicated tenant migration accounts" do
    grants = described_class.tenant_migration_statements(
      database: "development_localfind_tenant_42",
      account: "tenant_42_migrator"
    )

    expect(grants).to eq([
      "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES ON `development_localfind_tenant_42`.* TO 'tenant_42_migrator'@'%'"
    ])
  end

  it "generates revoke statements for master tenant wildcard patterns" do
    stmts = described_class.revoke_tenant_pattern_statements(
      account: "localfind_main",
      tenant_database_pattern: "development\\_localfind\\_tenant\\_%"
    )

    expect(stmts).to eq([
      "REVOKE ALL PRIVILEGES ON `development\\_localfind\\_tenant\\_%`.* FROM 'localfind_main'@'%'"
    ])
  end

  it "adds catalog and legacy listing writes only in the isolated test database" do
    grants = described_class.statements(
      service: :main,
      database: "local_find_test",
      account: "localfind_main",
      tenant_database_pattern: "test\\_localfind\\_tenant\\_%",
      allow_test_catalog_writes: true
    )

    expect(grants).to include(
      "GRANT SELECT, INSERT, UPDATE, DELETE ON `local_find_test`.`categories` TO 'localfind_main'@'%'"
    )
    expect(grants).to include(
      "GRANT SELECT, INSERT, UPDATE, DELETE ON `local_find_test`.`product_listings` TO 'localfind_main'@'%'"
    )
  end
end
