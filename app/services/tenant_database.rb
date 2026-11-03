class TenantDatabase
  SHARED_TABLES_IN_TENANTS = %w[
    cart_items
    listing_references
    carts
    login_audits
    tenants
    products
    categories
    discounts
    login_attempts
    users
  ].freeze
  TENANT_METADATA_TABLES = %w[schema_migrations ar_internal_metadata].freeze
  OWNERSHIP_TABLE = "localfind_tenant_ownership"
  REQUIRED_LEGACY_TABLES = %w[product_listings purchase_histories].freeze

  class Error < StandardError; end
  class OwnershipError < Error; end
  class MigrationRequired < Error; end
  class SharedTableDataError < Error; end

  def self.switch(tenant, &block)
    database_name = database_name_for(tenant)
    verify_database_exists!(database_name)
    verify_ownership!(tenant, database_name)

    if migration_marker_available? && !migration_complete?(tenant)
      raise MigrationRequired,
            "Tenant #{tenant.id} database has not been migrated and verified; run tenant_databases:migrate first"
    end

    Apartment::Tenant.switch(tenant.apartment_tenant_name, &block)
  end

  def self.provision!(tenant)
    tenant.with_lock do
      tenant.reload
      database_name = database_name_for(tenant)
      databases = Apartment.connection.select_values("SHOW DATABASES")

      if databases.include?(database_name)
        verify_ownership!(tenant, database_name)
        raise MigrationRequired, "Tenant #{tenant.id} database has not completed legacy-data migration" if
          migration_marker_available? && !migration_complete?(tenant)

        :existing
      else
        if migration_marker_available? && tenant.database_migrated_at?
          raise Error, "Tenant #{tenant.id} database is missing despite its migration marker"
        end

        Apartment::Tenant.create(tenant.apartment_tenant_name) do
          remove_shared_tables!
          create_ownership_marker!(tenant.id)
        end
        :created
      end
    end
  end

  def self.provision_new!(tenant)
    result = provision!(tenant)
    if result == :created
      if migration_marker_available?
        tenant.update_columns(database_migrated_at: Time.current, database_migration_source: nil)
      end
    elsif migration_marker_available? && !migration_complete?(tenant)
      raise MigrationRequired, "Tenant #{tenant.id} already has an unverified database"
    end
    result
  end

  def self.migrate_legacy_data!(tenant, legacy_database: nil, no_legacy: false)
    tenant.with_lock do
      tenant.reload
      target_database = database_name_for(tenant)
      provision!(tenant) unless database_exists?(target_database)
      verify_database_exists!(target_database)
      verify_ownership!(tenant, target_database)

      source_database = legacy_database || legacy_database_name_for(tenant)
      recorded_source = nil
      if source_database == target_database
        unless no_legacy
          raise Error,
                "Legacy database resolves to the stable tenant database; use NO_LEGACY=1 only after verifying no separate legacy data exists"
        end
      elsif database_exists?(source_database)
        verify_ownership!(tenant, source_database)
        copy_legacy_data!(tenant, source_database, target_database)
        recorded_source = source_database
      elsif !no_legacy
        raise Error,
              "Legacy tenant database #{source_database} was not found; confirm there is no legacy data before marking migration complete"
      end

      if migration_marker_available?
        tenant.update_columns(
          database_migrated_at: Time.current,
          database_migration_source: recorded_source
        )
      end
    end
  end

  def self.verify_migration!(tenant, legacy_database: nil)
    target_database = database_name_for(tenant)
    verify_database_exists!(target_database)
    verify_ownership!(tenant, target_database)
    unless migration_complete?(tenant)
      raise MigrationRequired, "Tenant #{tenant.id} has no verified migration marker"
    end

    source_database = legacy_database || tenant.database_migration_source
    if source_database.present? && source_database != target_database
      verify_database_exists!(source_database)
      verify_ownership!(tenant, source_database)
      verify_legacy_copy!(source_database, target_database)
    end

    true
  end

  def self.adopt_ownership!(tenant, database_name:)
    unless database_exists?(database_name)
      raise Error, "Cannot attest ownership: database #{database_name} does not exist"
    end

    connection = Apartment.connection
    tables = connection.select_values(
      "SHOW TABLES FROM #{connection.quote_table_name(database_name)}"
    )
    marker_table = connection.quote_table_name("#{database_name}.#{OWNERSHIP_TABLE}")

    unless tables.include?(OWNERSHIP_TABLE)
      connection.create_table("#{database_name}.#{OWNERSHIP_TABLE}", id: false) do |table|
        table.bigint :tenant_id, null: false, primary_key: true
        table.datetime :created_at, null: false
      end
    end

    record_ownership!(tenant.id, marker_table, connection)
  end

  def self.migration_complete?(tenant)
    migration_marker_available? && tenant.database_migrated_at?
  end

  def self.migration_marker_available?
    Tenant.column_names.include?("database_migrated_at")
  end

  def self.database_name_for(tenant)
    Apartment::Tenant.environmentify(tenant.apartment_tenant_name)
  end

  def self.legacy_database_name_for(tenant)
    Apartment::Tenant.environmentify(tenant.slug)
  end

  def self.verify_ownership!(tenant, database_name)
    verify_database_exists!(database_name)
    connection = Apartment.connection
    tables = connection.select_values(
      "SHOW TABLES FROM #{connection.quote_table_name(database_name)}"
    )
    unless tables.include?(OWNERSHIP_TABLE)
      raise OwnershipError,
            "Database #{database_name} has no ownership marker; verify it manually and run tenant_databases:adopt"
    end

    marker_table = connection.quote_table_name("#{database_name}.#{OWNERSHIP_TABLE}")
    owners = connection.select_values("SELECT tenant_id FROM #{marker_table}").map(&:to_i)
    unless owners == [ tenant.id ]
      raise OwnershipError,
            "Database #{database_name} is marked for tenant #{owners.join(', ')}; refusing to use it for tenant #{tenant.id}"
    end

    true
  end

  def self.verify_database_exists!(database_name)
    return if database_exists?(database_name)

    raise Error, "Tenant database #{database_name} does not exist"
  end

  def self.database_exists?(database_name)
    Apartment.connection.select_values("SHOW DATABASES").include?(database_name)
  end

  def self.create_ownership_marker!(tenant_id)
    connection = Apartment.connection
    connection.create_table(OWNERSHIP_TABLE, id: false) do |table|
      table.bigint :tenant_id, null: false, primary_key: true
      table.datetime :created_at, null: false
    end
    marker_table = connection.quote_table_name(OWNERSHIP_TABLE)
    record_ownership!(tenant_id, marker_table, connection)
  end

  def self.record_ownership!(tenant_id, marker_table, connection)
    owners = connection.select_values("SELECT tenant_id FROM #{marker_table}").map(&:to_i)
    if owners.empty?
      connection.execute(<<~SQL.squish)
        INSERT INTO #{marker_table} (tenant_id, created_at)
        VALUES (#{connection.quote(tenant_id)}, #{connection.quote(Time.current)})
      SQL
      return true
    end

    return true if owners == [ tenant_id ]

    raise OwnershipError,
          "Database ownership marker contains tenant #{owners.join(', ')}; refusing to assign it to tenant #{tenant_id}"
  end

  def self.copy_legacy_data!(tenant, source_database, target_database)
    verify_ownership!(tenant, source_database)
    verify_ownership!(tenant, target_database)

    connection = Apartment.connection
    source_tables = tables_for(source_database, connection)
    target_tables = tables_for(target_database, connection)
    missing_required = REQUIRED_LEGACY_TABLES - source_tables
    if missing_required.any?
      raise MigrationRequired,
            "Legacy database #{source_database} is missing expected tenant tables: #{missing_required.join(', ')}"
    end

    tables_to_copy = source_tables - SHARED_TABLES_IN_TENANTS - TENANT_METADATA_TABLES - [ OWNERSHIP_TABLE ]
    prepared_tables = tables_to_copy.map do |table|
      unless target_tables.include?(table)
        raise MigrationRequired,
              "Tenant database #{target_database} is missing table #{table} required to preserve legacy data"
      end

      source_table = connection.quote_table_name("#{source_database}.#{table}")
      target_table = connection.quote_table_name("#{target_database}.#{table}")
      source_columns = columns_for(source_table, connection)
      target_columns = columns_for(target_table, connection)
      missing_columns = source_columns - target_columns
      if missing_columns.any?
        raise MigrationRequired,
              "Tenant database #{target_database}.#{table} is missing legacy columns: #{missing_columns.join(', ')}"
      end

      primary_keys = primary_keys_for(source_table, connection)
      if primary_keys.empty?
        raise MigrationRequired,
              "Cannot safely copy legacy table #{source_database}.#{table} without a primary key"
      end

      [ table, source_table, target_table, source_columns, primary_keys ]
    end

    connection.transaction do
      prepared_tables.each do |table, source_table, target_table, columns, primary_keys|
        quoted_columns = columns.map { |column| connection.quote_column_name(column) }.join(", ")
        connection.execute(<<~SQL.squish)
          INSERT IGNORE INTO #{target_table} (#{quoted_columns})
          SELECT #{quoted_columns} FROM #{source_table}
        SQL
        verify_table_copy!(table, source_table, target_table, columns, primary_keys, connection)
      end
    end

    true
  end

  def self.verify_legacy_copy!(source_database, target_database)
    connection = Apartment.connection
    source_tables = tables_for(source_database, connection)
    target_tables = tables_for(target_database, connection)
    tables_to_verify = source_tables - SHARED_TABLES_IN_TENANTS - TENANT_METADATA_TABLES - [ OWNERSHIP_TABLE ]

    missing_required = REQUIRED_LEGACY_TABLES - source_tables
    if missing_required.any?
      raise MigrationRequired,
            "Legacy database #{source_database} is missing expected tenant tables: #{missing_required.join(', ')}"
    end

    tables_to_verify.each do |table|
      unless target_tables.include?(table)
        raise MigrationRequired, "Tenant database #{target_database} is missing legacy table #{table}"
      end

      source_table = connection.quote_table_name("#{source_database}.#{table}")
      target_table = connection.quote_table_name("#{target_database}.#{table}")
      columns = columns_for(source_table, connection)
      missing_columns = columns - columns_for(target_table, connection)
      if missing_columns.any?
        raise MigrationRequired,
              "Tenant database #{target_database}.#{table} is missing legacy columns: #{missing_columns.join(', ')}"
      end
      primary_keys = primary_keys_for(source_table, connection)
      if primary_keys.empty?
        raise MigrationRequired,
              "Cannot verify legacy table #{source_database}.#{table} without a primary key"
      end

      verify_table_copy!(table, source_table, target_table, columns, primary_keys, connection)
    end
    true
  end

  def self.verify_table_copy!(table, source_table, target_table, columns, primary_keys, connection)
    quoted_primary_keys = primary_keys.map { |column| connection.quote_column_name(column) }
    key_match = quoted_primary_keys.map do |column|
      "legacy.#{column} = stable.#{column}"
    end.join(" AND ")
    value_match = columns.map do |column|
      quoted_column = connection.quote_column_name(column)
      "legacy.#{quoted_column} <=> stable.#{quoted_column}"
    end.join(" AND ")
    missing_key = "stable.#{quoted_primary_keys.first} IS NULL"
    mismatch_count = connection.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM #{source_table} AS legacy
      LEFT JOIN #{target_table} AS stable ON #{key_match}
      WHERE #{missing_key} OR NOT (#{value_match})
    SQL
    return if mismatch_count.zero?

    raise MigrationRequired,
          "Legacy rows from #{source_table} were not fully copied to #{target_table} (#{table})"
  end

  def self.tables_for(database_name, connection)
    connection.select_values(
      "SHOW TABLES FROM #{connection.quote_table_name(database_name)}"
    )
  end

  def self.columns_for(qualified_table, connection)
    connection.select_values("SHOW COLUMNS FROM #{qualified_table}")
  end

  def self.primary_keys_for(qualified_table, connection)
    connection.select_all(
      "SHOW KEYS FROM #{qualified_table} WHERE Key_name = 'PRIMARY'"
    ).map { |row| row.fetch("Column_name") }
  end

  def self.remove_shared_tables!
    connection = ActiveRecord::Base.connection
    existing_tables = SHARED_TABLES_IN_TENANTS.select do |table|
      connection.data_source_exists?(table)
    end

    tables_with_data = existing_tables.filter_map do |table|
      quoted_table = connection.quote_table_name(table)
      row_count = connection.select_value("SELECT COUNT(*) FROM #{quoted_table}").to_i
      "#{table} (#{row_count} rows)" if row_count.positive?
    end

    if tables_with_data.any?
      raise SharedTableDataError,
            "Refusing to remove tenant copies of shared tables containing data: #{tables_with_data.join(', ')}"
    end

    existing_tables.each do |table|
      connection.drop_table(table)
    end
  end
end
