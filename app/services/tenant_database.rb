class TenantDatabase
  OWNERSHIP_TABLE = "localfind_tenant_ownership"
  MIGRATIONS_TABLE = "tenant_schema_migrations"

  class Error < StandardError; end
  class OwnershipError < Error; end

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
end

  # Switch to a tenant database only after verifying ownership.
  def self.switch(tenant, &block)
  raise ArgumentError, "Tenant is required" unless tenant
  raise ArgumentError, "Block is required" unless block

  database_name = database_name_for(tenant)

  verify_database_exists!(database_name)
  verify_ownership!(tenant, database_name)

  previous_tenant = CurrentTenantContext.tenant

  CurrentTenantContext.set(tenant: tenant) do
    TenantConnectionManager.with_tenant(tenant, &block)
  end
  ensure
  CurrentTenantContext.tenant = previous_tenant if defined?(previous_tenant)
  end

  # Create a tenant database and initialize its schema.
  def self.provision!(tenant)
    tenant.with_lock do
      tenant.reload

      database_name = database_name_for(tenant)

      if database_exists?(database_name)
        verify_ownership!(tenant, database_name)

        tenant.ensure_db_credentials! if tenant.respond_to?(:ensure_db_credentials!)

        provision_mysql_account!(tenant, database_name) if tenant.db_username.present?

        verify_tenant_access!(tenant, database_name)
        return :existing
      end

      tenant.ensure_db_credentials! if tenant.respond_to?(:ensure_db_credentials!)

      created_database = false

      begin
        create_empty_tenant_database!(database_name)
        created_database = true

        create_ownership_marker!(database_name, tenant.id)

        TenantSchemaMigrator.migrate!(
          database_name: database_name,
          tenant_id: tenant.id
        )

        provision_mysql_account!(tenant, database_name) if tenant.db_username.present?

        verify_tenant_access!(tenant, database_name)

        :created
      rescue StandardError => error
        # Remove the tenant account if it was created or partially created.
        deprovision_mysql_account!(tenant)

        # Drop only a database created by this provisioning attempt.
        drop_database!(database_name) if created_database

        raise error
      end
    end
  end

  # Use the privileged MySQL account only for provisioning operations.
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

  # Create an empty database. Do not import the main Rails schema.
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

  # Create or refresh the tenant's restricted application account.
  def self.provision_mysql_account!(tenant, database_name)
    return unless tenant.db_username.present? && tenant.db_password.present?

    user_sql = LocalFindShared::DatabaseAccess.quote_account(
      tenant.db_username
    )

    escaped_password = nil

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

  # Remove the tenant's MySQL account during provisioning rollback.
  def self.deprovision_mysql_account!(tenant)
    return unless tenant.respond_to?(:db_username) && tenant.db_username.present?

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

  # Rotate the tenant's database password.
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
    end
  end

  def self.database_name_for(tenant)
    Apartment::Tenant.environmentify(tenant.apartment_tenant_name)
  end

  # Check database existence using the provisioner, not the app account.
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

  # Check that the database has exactly the expected owner.
  def self.verify_ownership!(tenant, database_name)
    verify_database_exists!(database_name)

    with_provisioner_client do |client|
      tables = client.query(
        "SHOW TABLES FROM #{quote_identifier(database_name)}"
      ).map { |row| row.values.first }

      unless tables.include?(OWNERSHIP_TABLE)
        raise OwnershipError,
          "Database #{database_name} has no ownership marker"
      end

      result = client.query(
        "SELECT tenant_id FROM #{quote_identifier(database_name)}." \
        "#{quote_identifier(OWNERSHIP_TABLE)}"
      )

      owners = result.map { |row| row["tenant_id"].to_i }

      unless owners == [ tenant.id ]
        raise OwnershipError,
          "Database #{database_name} is marked for tenant " \
          "#{owners.join(', ')}, not tenant #{tenant.id}"
      end
    end

    true
  end

  def self.verify_tenant_access!(tenant, database_name)
    verify_database_exists!(database_name)
    verify_ownership!(tenant, database_name)
    true
  end

  def self.quote_identifier(value)
    raise ArgumentError, "Invalid database identifier" unless
      value.to_s.match?(/\A[a-zA-Z0-9_]+\z/)

    "`#{value}`"
  end

  private_class_method :quote_identifier
end
