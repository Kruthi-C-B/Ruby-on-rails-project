require "bundler/setup"
require "mysql2"
require_relative "../shared/localfind_shared/lib/localfind_shared"

environment = ENV.fetch("RAILS_ENV", "development")
databases = if environment == "production"
  [ ENV.fetch("LOCALFIND_DATABASE_NAME", "local_find_production") ]
else
  [ "local_find_development", "local_find_test" ]
end
accounts = {
  main: [
    ENV.fetch("LOCALFIND_MAIN_DB_USERNAME", "localfind_main"),
    ENV.fetch("LOCALFIND_MAIN_DB_PASSWORD")
  ],
  admin_dashboard: [
    ENV.fetch("ADMIN_DASHBOARD_DB_USERNAME", "localfind_admin_dashboard"),
    ENV.fetch("ADMIN_DASHBOARD_DB_PASSWORD")
  ],
  security_logs: [
    ENV.fetch("SECURITY_LOGS_DB_USERNAME", "localfind_security_logs"),
    ENV.fetch("SECURITY_LOGS_DB_PASSWORD")
  ]
}
client = Mysql2::Client.new(
  host: ENV.fetch("DB_PROVISIONER_HOST", ENV.fetch("DB_HOST", "db")),
  port: ENV.fetch("DB_PORT", "3306").to_i,
  username: ENV.fetch("DB_PROVISIONER_USERNAME", "root"),
  password: ENV.fetch("DB_PROVISIONER_PASSWORD")
)

isolate_tenants = ENV["ISOLATE_TENANT_CREDENTIALS"] == "1" || environment == "production"

begin
  accounts.each do |service, (username, password)|
    user_sql = LocalFindShared::DatabaseAccess.quote_account(username)
    escaped_password = client.escape(password)
    client.query("CREATE USER IF NOT EXISTS #{user_sql} IDENTIFIED BY '#{escaped_password}'")
    client.query("ALTER USER #{user_sql} IDENTIFIED BY '#{escaped_password}'")
    client.query("REVOKE ALL PRIVILEGES, GRANT OPTION FROM #{user_sql}")

    databases.each do |database|
      tenant_prefix = database == "local_find_test" ? "test_" : "development_"
      tenant_pattern = "#{tenant_prefix}localfind\\_tenant\\_%"
      LocalFindShared::DatabaseAccess.statements(
        service: service,
        database: database,
        account: username,
        tenant_database_pattern: service == :main ? tenant_pattern : nil,
        allow_test_catalog_writes: service == :main && database == "local_find_test",
        isolated_app: isolate_tenants
      ).each { |grant| client.query(grant) }
      puts "Provisioned #{service} database account for #{database}"
    end
  end
ensure
  client&.close
end
