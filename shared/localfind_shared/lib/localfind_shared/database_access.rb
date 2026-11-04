module LocalFindPramata
  module DatabaseAccess
    MAIN_WRITE_TABLES = %w[
      users tenants carts cart_items listing_references login_audits login_attempts
    ].freeze
    MAIN_READ_TABLES = %w[categories products discounts].freeze
    MAIN_AUDIT_TABLE = "versions"
    MAIN_TEST_ONLY_TABLES = %w[product_listings purchase_histories].freeze
    ADMIN_WRITE_TABLES = %w[categories products discounts].freeze
    ADMIN_INSERT_TABLES = %w[versions].freeze
    ADMIN_READ_COLUMNS = {
      "users" => %w[id email is_admin platform_admin created_at],
      "tenants" => %w[id name user_id created_at],
      "carts" => %w[id status],
      "listing_references" => %w[product_id]
    }.freeze
    SECURITY_LOGS_READ_COLUMNS = {
      "login_audits" => %w[id email ip_address status failure_reason created_at user_id]
    }.freeze
    METADATA_TABLES = %w[schema_migrations ar_internal_metadata].freeze
    DATA_WRITE_PRIVILEGES = %w[SELECT INSERT UPDATE DELETE].freeze

    def self.statements(service:, database:, account:, host: "%", tenant_database_pattern: nil,
                        allow_test_catalog_writes: false)
      user = quote_account(account)
      grants = case service
      when :main
        MAIN_WRITE_TABLES.map { |table| "#{DATA_WRITE_PRIVILEGES.join(', ')} ON #{quote_table(database, table)} TO #{user}" } +
          [ "SELECT, INSERT ON #{quote_table(database, MAIN_AUDIT_TABLE)} TO #{user}" ] +
          main_read_grants(database, user, allow_test_catalog_writes) +
          main_test_table_grants(database, user, allow_test_catalog_writes) +
          [ "CREATE ON *.* TO #{user}" ]
      when :admin_dashboard
        ADMIN_WRITE_TABLES.map { |table| "#{DATA_WRITE_PRIVILEGES.join(', ')} ON #{quote_table(database, table)} TO #{user}" } +
          ADMIN_INSERT_TABLES.map { |table| "INSERT ON #{quote_table(database, table)} TO #{user}" } +
          column_select_grants(database, ADMIN_READ_COLUMNS, user)
      when :security_logs
        column_select_grants(database, SECURITY_LOGS_READ_COLUMNS, user)
      else
        raise ArgumentError, "Unknown database service: #{service}"
      end

      grants.concat(METADATA_TABLES.map { |table| "SELECT ON #{quote_table(database, table)} TO #{user}" })
      if service == :main && tenant_database_pattern
        grants << "ALL PRIVILEGES ON #{quote_identifier(tenant_database_pattern)}.* TO #{user}"
      end
      grants.map { |grant| "GRANT #{grant}" }
    end

    def self.main_read_grants(database, user, allow_test_catalog_writes)
      MAIN_READ_TABLES.map do |table|
        privileges = allow_test_catalog_writes ? DATA_WRITE_PRIVILEGES.join(", ") : "SELECT"
        "#{privileges} ON #{quote_table(database, table)} TO #{user}"
      end
    end
    private_class_method :main_read_grants

    def self.main_test_table_grants(database, user, allow_test_catalog_writes)
      return [] unless allow_test_catalog_writes

      (MAIN_TEST_ONLY_TABLES + [ MAIN_AUDIT_TABLE ]).map do |table|
        "#{DATA_WRITE_PRIVILEGES.join(', ')} ON #{quote_table(database, table)} TO #{user}"
      end
    end
    private_class_method :main_test_table_grants

    def self.quote_account(account, host = "%")
      "'#{account.to_s.gsub("\\", "\\\\\\\\").gsub("'", "''")}'@'#{host.to_s.gsub("\\", "\\\\\\\\").gsub("'", "''")}'"
    end

    def self.quote_identifier(value)
      "`#{value.to_s.gsub("`", "``")}`"
    end
    private_class_method :quote_identifier

    def self.quote_table(database, table)
      "#{quote_identifier(database)}.#{quote_identifier(table)}"
    end
    private_class_method :quote_table

    def self.column_select_grants(database, columns_by_table, user)
      columns_by_table.map do |table, columns|
        columns_sql = columns.map { |column| quote_identifier(column) }.join(", ")
        "SELECT (#{columns_sql}) ON #{quote_table(database, table)} TO #{user}"
      end
    end
    private_class_method :column_select_grants
  end
end
