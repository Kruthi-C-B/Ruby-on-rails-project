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

  OWNERSHIP_TABLE = "localfind_tenant_ownership"

  class Error < StandardError; end
  class OwnershipError < Error; end
  class SharedTableDataError < Error; end

  # Switch to the selected store's database.
  def self.switch(tenant, &block)
    database_name = database_name_for(tenant)

    verify_database_exists!(database_name)
    verify_ownership!(tenant, database_name)

    Apartment::Tenant.switch(tenant.apartment_tenant_name, &block)
  end

  # Create a database for a store if it does not already exist.
  def self.provision!(tenant)
    tenant.with_lock do
      tenant.reload

      database_name = database_name_for(tenant)

      if database_exists?(database_name)
        verify_ownership!(tenant, database_name)
        :existing
      else
        Apartment::Tenant.create(tenant.apartment_tenant_name) do
          remove_shared_tables!
          create_ownership_marker!(tenant.id)
        end

        :created
      end
    end
  end

  # Return the database name for a store.
  def self.database_name_for(tenant)
    Apartment::Tenant.environmentify(tenant.apartment_tenant_name)
  end

  # Check whether the database exists.
  def self.database_exists?(database_name)
    Apartment.connection
      .select_values("SHOW DATABASES")
      .include?(database_name)
  end

  # Raise an error if the database does not exist.
  def self.verify_database_exists!(database_name)
    return if database_exists?(database_name)

    raise Error, "Tenant database #{database_name} does not exist"
  end

  # Verify that the database belongs to the requested store.
  def self.verify_ownership!(tenant, database_name)
    verify_database_exists!(database_name)

    connection = Apartment.connection

    tables = connection.select_values(
      "SHOW TABLES FROM #{connection.quote_table_name(database_name)}"
    )

    unless tables.include?(OWNERSHIP_TABLE)
      raise OwnershipError,
            "Database #{database_name} has no ownership marker"
    end

    marker_table = connection.quote_table_name(
      "#{database_name}.#{OWNERSHIP_TABLE}"
    )

    owners = connection
      .select_values("SELECT tenant_id FROM #{marker_table}")
      .map(&:to_i)

    unless owners == [ tenant.id ]
      raise OwnershipError,
            "Database #{database_name} belongs to tenant #{owners.join(', ')}, " \
            "not tenant #{tenant.id}"
    end

    true
  end

  # Create the ownership marker inside a newly created tenant database.
  def self.create_ownership_marker!(tenant_id)
    connection = ActiveRecord::Base.connection

    connection.create_table(OWNERSHIP_TABLE, id: false) do |table|
      table.bigint :tenant_id, null: false, primary_key: true
      table.datetime :created_at, null: false
    end

    marker_table = connection.quote_table_name(OWNERSHIP_TABLE)

    connection.execute(<<~SQL.squish)
      INSERT INTO #{marker_table} (tenant_id, created_at)
      VALUES (
        #{connection.quote(tenant_id)},
        #{connection.quote(Time.current)}
      )
    SQL
  end

  # Remove shared tables from a newly created tenant database.
  def self.remove_shared_tables!
    connection = ActiveRecord::Base.connection

    existing_tables = SHARED_TABLES_IN_TENANTS.select do |table|
      connection.data_source_exists?(table)
    end

    tables_with_data = existing_tables.filter_map do |table|
      quoted_table = connection.quote_table_name(table)

      row_count = connection
        .select_value("SELECT COUNT(*) FROM #{quoted_table}")
        .to_i

      "#{table} (#{row_count} rows)" if row_count.positive?
    end

    if tables_with_data.any?
      raise SharedTableDataError,
            "Refusing to remove shared tables containing data: " \
            "#{tables_with_data.join(', ')}"
    end

    existing_tables.each do |table|
      connection.drop_table(table)
    end
  end
end
