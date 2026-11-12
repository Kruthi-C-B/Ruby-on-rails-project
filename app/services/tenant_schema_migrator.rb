
# app/services/tenant_schema_migrator.rb
require "digest"

class TenantSchemaMigrator
  MIGRATIONS_PATH = Rails.root.join("db/tenant_migrate")

  OWNERSHIP_TABLE = "localfind_tenant_ownership"
  MIGRATIONS_TABLE = "tenant_schema_migrations"
  LOCK_TIMEOUT_SECONDS = 30

  class Error < StandardError; end

  # def self.migrate!(database_name:, tenant_id:)
  #   validate_database_name!(database_name)

  #   connection_class = build_connection_class(database_name)

  #   begin
  #     connection = connection_class.connection

  #     # Verify ownership before applying any schema changes.
  #     verify_ownership!(connection, tenant_id)

  #     create_migration_table!(connection)

  #     applied_versions = connection.select_values(
  #       "SELECT version FROM #{quote_table(connection, MIGRATIONS_TABLE)}"
  #     )

  #     migration_files.each do |file|
  #       version = File.basename(file).split("_", 2).first

  #       next if applied_versions.include?(version)

  #       migration_class = load_migration_class(file)

  #       Rails.logger.info(
  #         "Running tenant migration #{version}: #{migration_class.name}"
  #       )

  #       migration_class.up(connection)

  #       record_migration!(connection, version)
  #     end

  #     true
  #   ensure
  #     connection_class.connection_pool.disconnect! if connection_class
  #   end
  # end


def self.migrate!(database_name:, tenant_id:)
 raise ArgumentError, "Invalid tenant ID" unless
  tenant_id.to_s.match?(/\A[1-9]\d*\z/)

  validate_database_name!(database_name)

  connection_class = build_connection_class(database_name)

  begin
    connection_class.connection_pool.with_connection do |connection|
      lock_name = migration_lock_name(database_name)

      acquire_migration_lock!(connection, lock_name)

      begin
        # Verify ownership before making any schema changes.
        verify_ownership!(connection, tenant_id)

        create_migration_table!(connection)

        applied_versions = connection.select_values(
          "SELECT version FROM #{quote_table(connection, MIGRATIONS_TABLE)}"
        )

        migration_files.each do |file|
          version = File.basename(file).split("_", 2).first

          next if applied_versions.include?(version)

          migration_class = load_migration_class(file)

          Rails.logger.info(
            "Running tenant migration #{version}: #{migration_class.name}"
          )

          migration_class.up(connection)

          record_migration!(connection, version)

          # Keep the in-memory list synchronized.
          applied_versions << version
        end

        true
      ensure
        release_migration_lock!(connection, lock_name)
      end
    end
  ensure
    connection_class.connection_pool.disconnect! if connection_class
  end
end


# Establish a separate connection using provisioning credentials.

# def self.build_connection_class(database_name)
#   config = {
#     adapter: "mysql2",
#     encoding: "utf8mb4",
#     host: ENV.fetch("DB_PROVISIONER_HOST", ENV.fetch("DB_HOST", "db")),
#     port: ENV.fetch("DB_PORT", "3306").to_i,
#     username: ENV.fetch("DB_PROVISIONER_USERNAME", "root"),
#     password: ENV.fetch(
#       "DB_PROVISIONER_PASSWORD",
#       ENV.fetch("MYSQL_ROOT_PASSWORD", "password")
#     ),
#     database: database_name,
#     pool: 1
#   }

#   unless Object.const_defined?(:TenantMigrationConnection, false)
#     Object.const_set(
#       :TenantMigrationConnection,
#       Class.new(ActiveRecord::Base)
#     )
#   end

#   connection_class = Object.const_get(:TenantMigrationConnection)
#   connection_class.abstract_class = true
#   connection_class.establish_connection(config)

#   connection_class
# end
# private_class_method :build_connection_class


def self.build_connection_class(database_name)
  config = {
    adapter: "mysql2",
    encoding: "utf8mb4",
    host: ENV.fetch("DB_PROVISIONER_HOST", ENV.fetch("DB_HOST", "db")),
    port: ENV.fetch("DB_PORT", "3306").to_i,
    username: ENV.fetch("DB_PROVISIONER_USERNAME", "root"),
    password: ENV.fetch(
      "DB_PROVISIONER_PASSWORD",
      ENV.fetch("MYSQL_ROOT_PASSWORD", "password")
    ),
    database: database_name,
    pool: 1
  }

  class_name = "TenantMigrationConnection"

  unless Object.const_defined?(class_name, false)
    Object.const_set(
      class_name,
      Class.new(ActiveRecord::Base)
    )
  end

  connection_class = Object.const_get(class_name)

  connection_class.abstract_class = true
  connection_class.establish_connection(config)

  connection_class
end

private_class_method :build_connection_class


  # Only permit valid MySQL database identifiers.
  def self.validate_database_name!(database_name)
    return if database_name.to_s.match?(/\A[a-zA-Z0-9_]+\z/)

    raise ArgumentError, "Invalid tenant database name: #{database_name.inspect}"
  end
  private_class_method :validate_database_name!

  # Discover tenant migration files in version order.
def self.migration_files
  files = Dir.glob(MIGRATIONS_PATH.join("*.rb").to_s).sort

  if files.empty?
    raise Error, "No tenant migrations found in #{MIGRATIONS_PATH}"
  end

  versions = files.map do |file|
    File.basename(file).split("_", 2).first
  end

  unless versions.all? { |version| version.match?(/\A\d{3}\z/) }
    raise Error, "Invalid tenant migration filename"
  end

  if versions.uniq.length != versions.length
    raise Error, "Duplicate tenant migration versions detected"
  end

  files
end

private_class_method :migration_files

  # Load and resolve the migration class.
  def self.load_migration_class(file)
    load file

    class_name = File.basename(file)
      .split("_", 2)
      .last
      .delete_suffix(".rb")
      .camelize

    migration_class = "TenantMigrations::#{class_name}".constantize

    unless migration_class.respond_to?(:up)
      raise Error, "#{migration_class} must define an up(connection) method"
    end

    migration_class
  end
  private_class_method :load_migration_class

  # Create the tenant migration tracking table.
  def self.create_migration_table!(connection)
    table = quote_table(connection, MIGRATIONS_TABLE)

    connection.create_table(
      MIGRATIONS_TABLE,
      id: false,
      if_not_exists: true
    ) do |t|
      t.string :version, null: false, limit: 191
    end

    connection.add_index(
      MIGRATIONS_TABLE,
      :version,
      unique: true,
      name: "index_tenant_schema_migrations_on_version",
      if_not_exists: true
    )

    table
  end
  private_class_method :create_migration_table!

  # Check that the database is already marked for this tenant.
  # This method deliberately does not create or adopt an ownership marker.
  def self.verify_ownership!(connection, tenant_id)
    unless connection.data_source_exists?(OWNERSHIP_TABLE)
      raise TenantDatabase::OwnershipError,
        "Tenant database has no ownership marker"
    end

    owners = connection.select_values(
      "SELECT tenant_id FROM #{quote_table(connection, OWNERSHIP_TABLE)}"
    ).map(&:to_i)

    unless owners == [ tenant_id.to_i ]
      raise TenantDatabase::OwnershipError,
        "Tenant database ownership mismatch. " \
        "Expected tenant #{tenant_id}, found #{owners.join(', ')}"
    end

    true
  end
  private_class_method :verify_ownership!

  # Record a completed migration.
  def self.record_migration!(connection, version)
    connection.execute(<<~SQL)
      INSERT INTO #{quote_table(connection, MIGRATIONS_TABLE)} (version)
      VALUES (#{connection.quote(version)})
    SQL
  end
  private_class_method :record_migration!

  def self.quote_table(connection, table_name)
    connection.quote_table_name(table_name)
  end
  private_class_method :quote_table



# Generate a deterministic MySQL lock name.
def self.migration_lock_name(database_name)
  digest = Digest::SHA256.hexdigest(database_name)[0, 48]

  "lf_tm_#{digest}"
end
private_class_method :migration_lock_name


# Acquire a MySQL advisory lock.
def self.acquire_migration_lock!(connection, lock_name)
  result = connection.select_value(
    "SELECT GET_LOCK(" \
    "#{connection.quote(lock_name)}, " \
    "#{LOCK_TIMEOUT_SECONDS})"
  )

  return true if result.to_s == "1"

  raise Error, "Could not acquire migration lock: #{lock_name}"
end
private_class_method :acquire_migration_lock!


# Release the MySQL advisory lock.
def self.release_migration_lock!(connection, lock_name)
  result = connection.select_value(
    "SELECT RELEASE_LOCK(#{connection.quote(lock_name)})"
  )

  unless result.to_s == "1"
    Rails.logger.warn(
      "Could not confirm release of migration lock: #{lock_name}"
    )
  end
rescue StandardError => error
  Rails.logger.error(
    "Failed to release migration lock #{lock_name}: #{error.message}"
  )
end
private_class_method :release_migration_lock!

end
