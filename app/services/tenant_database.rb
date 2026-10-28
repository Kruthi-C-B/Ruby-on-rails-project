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

  class SharedTableDataError < StandardError; end

  def self.switch(tenant, &block)
    Apartment::Tenant.switch(tenant.slug, &block)
  end

  def self.provision!(tenant)
    database_name = Apartment::Tenant.environmentify(tenant.slug)
    if Apartment.connection.select_values("SHOW DATABASES").include?(database_name)
      raise Apartment::TenantExists, "Tenant database #{database_name} already exists"
    end

    begin
      Apartment::Tenant.create(tenant.slug) do
        remove_shared_tables!
      end
    rescue StandardError
      databases = Apartment.connection.select_values("SHOW DATABASES")
      Apartment::Tenant.drop(tenant.slug) if databases.include?(database_name)
      raise
    end
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
