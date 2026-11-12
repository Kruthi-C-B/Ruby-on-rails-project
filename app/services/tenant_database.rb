require "concurrent/map"

class TenantDatabase
  OWNERSHIP_TABLE = "localfind_tenant_ownership"
  MIGRATIONS_TABLE = "tenant_schema_migrations"

  VERIFIED_TENANTS = Concurrent::Map.new
  VERIFICATION_CACHE_TTL = 5.minutes

  class Error < StandardError; end
  class OwnershipError < Error; end

  # --------------------------------------------------
  # TENANT OWNERSHIP MARKER
  # --------------------------------------------------

  def self.create_ownership_marker!(database_name, tenant_id)
    database = quote_identifier(database_name)
    table = quote_identifier(OWNERSHIP_TABLE)

    with_provisioner_client do |client|
      client.query(<<~SQL)
        CREATE TABLE #{database}.#{table} (
          tenant_id BIGINT NOT NULL PRIMARY KEY,
          created_at DATETIME NOT NULL
        ) ENGINE=InnoDB
      SQL

      client.query(<<~SQL)
        INSERT INTO #{database}.#{table} (tenant_id, created_at)
        VALUES (#{Integer(tenant_id)}, UTC_TIMESTAMP())
      SQL
    end

    invalidate_verification!(tenant_id)
  end

  # --------------------------------------------------
  # OWNERSHIP VERIFICATION WITH CACHE
  # --------------------------------------------------

  def self.verify_tenant!(tenant)
    raise ArgumentError, "Tenant is required" unless tenant

    database_name = database_name_for(tenant)
    cache_key = [tenant.id, database_name]

    verified_at = VERIFIED_TENANTS[cache_key]

    if verified_at &&
       Process.clock_gettime(Process::CLOCK_MONOTONIC) - verified_at <
         VERIFICATION_CACHE_TTL.to_f
      return true
    end

    verify_ownership!(tenant, database_name)

    VERIFIED_TENANTS[cache_key] =
      Process.clock_gettime(Process::CLOCK_MONOTONIC)

    true
  end

  def self.invalidate_verification!(tenant_or_id)
    tenant_id = tenant_or_id.respond_to?(:id) ?
      tenant_or_id.id : tenant_or_id

    VERIFIED_TENANTS.each_key do |key|
      VERIFIED_TENANTS.delete(key) if key.first == tenant_id
    end
  end

  # --------------------------------------------------
  # TENANT SWITCHING
  # --------------------------------------------------

  def self.switch(tenant, &block)
    raise ArgumentError, "Tenant is required" unless tenant
    raise ArgumentError, "Block is required" unless block

    verify_tenant!(tenant)

    previous_tenant = CurrentTenantContext.tenant

    CurrentTenantContext.set(tenant: tenant) do
      TenantConnectionManager.with_tenant(tenant, &block)
    end
  ensure
    CurrentTenantContext.tenant = previous_tenant if
      defined?(previous_tenant)
  end

  # --------------------------------------------------
  # DATABASE PROVISIONING
  # --------------------------------------------------

  def self.provision!(tenant)
    tenant.with_lock do
      tenant.reload

      database_name = database_name_for(tenant)

      if database_exists?(database_name)
        verify_ownership!(tenant, database_name)

        tenant.ensure_db_credentials! if
          tenant.respond_to?(:ensure_db_credentials!)

        provision_mysql_account!(tenant, database_name) if
          tenant.db_username.present?

        verify_tenant_access!(tenant, database_name)

        invalidate_verification!(tenant)

        return :existing
      end

      tenant.ensure_db_credentials! if
        tenant.respond_to?(:ensure_db_credentials!)

      created_database = false

      begin
        create_empty_tenant_database!(database_name)
        created_database = true

        create_ownership_marker!(database_name, tenant.id)

        TenantSchemaMigrator.migrate!(
          database_name: database_name,
          tenant_id: tenant.id
        )

        provision_mysql_account!(tenant, database_name) if
          tenant.db_username.present?

        verify_tenant_access!(tenant, database_name)

        invalidate_verification!(tenant)

        :created
      rescue StandardError => error
        deprovision_mysql_account!(tenant)

        drop_database!(database_name) if created_database

        invalidate_verification!(tenant)

        raise error
      end
    end
  end

  # --------------------------------------------------
  # PROVISIONER CONNECTION
  # --------------------------------------------------

  def self.with_provisioner_client
    host = ENV.fetch("DB_PROVISIONER_HOST", ENV.fetch("DB_HOST", "db"))
    port = ENV.fetch("DB_PORT", "3306").to_i
    username = ENV.fetch("DB_PROVISIONER_USERNAME", "root")

    password = ENV.fetch(
      "DB_PROVISIONER_PASSWORD",
      ENV.fetch("MYSQL_ROOT_PASSWORD", "password")
    )

    client = Mysql2::Client.new(
      host: host,
      port: port,
      username: username,
      password: password,
      encoding: "utf8mb4"
    )

    yield client
  ensure
    client&.close
  end

  def self.provisioner_available?
    ENV["DB_PROVISIONER_PASSWORD"].present? ||
      ENV["MYSQL_ROOT_PASSWORD"].present?
  end

  # --------------------------------------------------
  # DATABASE CREATION AND DELETION
  # --------------------------------------------------

  def self.create_empty_tenant_database!(database_name)
    identifier = quote_identifier(database_name)

    with_provisioner_client do |client|
      client.query(
        "CREATE DATABASE #{identifier} " \
        "CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
      )
    end
  end

  def self.drop_database!(database_name)
    identifier = quote_identifier(database_name)

    with_provisioner_client do |client|
      client.query("DROP DATABASE IF EXISTS #{identifier}")
    end
  end

  # --------------------------------------------------
  # TENANT MYSQL ACCOUNT
  # --------------------------------------------------

  def self.provision_mysql_account!(tenant, database_name)
    return unless tenant.db_username.present? &&
                  tenant.db_password.present?

    user_sql = LocalFindShared::DatabaseAccess.quote_account(
      tenant.db_username
    )

    with_provisioner_client do |client|
      escaped_password = client.escape(tenant.db_password)

      client.query(
        "CREATE USER IF NOT EXISTS #{user_sql} " \
        "IDENTIFIED BY '#{escaped_password}'"
      )

      client.query(
        "ALTER USER #{user_sql} IDENTIFIED BY '#{escaped_password}'"
      )

      client.query(
        "REVOKE ALL PRIVILEGES, GRANT OPTION FROM #{user_sql}"
      )

      LocalFindShared::DatabaseAccess.tenant_application_statements(
        database: database_name,
        account: tenant.db_username
      ).each do |statement|
        client.query(statement)
      end
    end
  end

  def self.deprovision_mysql_account!(tenant)
    return unless tenant.respond_to?(:db_username) &&
                  tenant.db_username.present?

    user_sql = LocalFindShared::DatabaseAccess.quote_account(
      tenant.db_username
    )

    with_provisioner_client do |client|
      client.query("DROP USER IF EXISTS #{user_sql}")
    end
  rescue StandardError => error
    Rails.logger.error(
      "Failed to drop MySQL account for tenant #{tenant.id}: #{error.message}"
    )
  end

  # --------------------------------------------------
  # CREDENTIAL ROTATION
  # --------------------------------------------------

  def self.rotate_credentials!(tenant, new_password = SecureRandom.base58(32))
    tenant.with_lock do
      tenant.reload

      user_sql = LocalFindShared::DatabaseAccess.quote_account(
        tenant.db_username
      )

      with_provisioner_client do |client|
        escaped_password = client.escape(new_password)

        client.query(
          "ALTER USER #{user_sql} IDENTIFIED BY '#{escaped_password}'"
        )
      end

      tenant.rotate_db_password!(new_password)

      invalidate_verification!(tenant)

      # Important:
      # TenantConnectionManager must also discard old
      # connections after credential rotation.
      TenantConnectionManager.disconnect_tenant!(tenant) if
        TenantConnectionManager.respond_to?(:disconnect_tenant!)
    end
  end

  # --------------------------------------------------
  # DATABASE NAME
  # --------------------------------------------------

  def self.database_name_for(tenant)
    Apartment::Tenant.environmentify(
      tenant.apartment_tenant_name
    )
  end

  # --------------------------------------------------
  # DATABASE EXISTENCE
  # --------------------------------------------------

  def self.database_exists?(database_name)
    with_provisioner_client do |client|
      result = client.query(
        "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA " \
        "WHERE SCHEMA_NAME = '#{client.escape(database_name)}'"
      )

      result.count.positive?
    end
  end

  def self.verify_database_exists!(database_name)
    return true if database_exists?(database_name)

    raise Error, "Tenant database #{database_name} does not exist"
  end

  # --------------------------------------------------
  # OWNERSHIP VERIFICATION
  # --------------------------------------------------

  def self.verify_ownership!(tenant, database_name)
    with_provisioner_client do |client|
      database_result = client.query(
        "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA " \
        "WHERE SCHEMA_NAME = '#{client.escape(database_name)}'"
      )

      unless database_result.count.positive?
        raise Error,
          "Tenant database #{database_name} does not exist"
      end

      result = client.query(
        "SELECT tenant_id FROM #{quote_identifier(database_name)}." \
        "#{quote_identifier(OWNERSHIP_TABLE)}"
      )

      owners = result.map { |row| row["tenant_id"].to_i }

      unless owners == [tenant.id]
        raise OwnershipError,
          "Database #{database_name} is marked for tenant " \
          "#{owners.join(', ')}, not tenant #{tenant.id}"
      end
    end

    true
  rescue Mysql2::Error => error
    raise OwnershipError,
      "Unable to verify ownership of tenant database: #{error.message}"
  end

  def self.verify_tenant_access!(tenant, database_name)
    verify_ownership!(tenant, database_name)
  end

  # --------------------------------------------------
  # SQL IDENTIFIER QUOTING
  # --------------------------------------------------

  def self.quote_identifier(value)
    raise ArgumentError, "Invalid database identifier" unless
      value.to_s.match?(/\A[a-zA-Z0-9_]+\z/)

    "`#{value}`"
  end

  private_class_method :quote_identifier
end
