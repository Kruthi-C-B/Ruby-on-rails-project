# frozen_string_literal: true

Apartment.configure do |config|
  config.excluded_models = %w[
    User
    Tenant
    Product
    Category
    ListingReference
    Cart
    CartItem
    Discount
    LoginAudit
    LoginAttempt
  ]

  config.prepend_environment = !Rails.env.production?
  config.db_migrate_tenant_missing_strategy = :create_tenant

  config.tenant_names = lambda do
    return {} unless ActiveRecord::Base.connected? && ActiveRecord::Base.connection.data_source_exists?("tenants")

    base_config = ActiveRecord::Base.configurations.configs_for(
      env_name: Rails.env,
      name: "primary"
    )&.configuration_hash || {}

    Tenant.all.to_h do |tenant|
      tenant_key = tenant.apartment_tenant_name
      db_name = Apartment::Tenant.environmentify(tenant_key)
      cfg = base_config.dup.symbolize_keys
      cfg[:database] = db_name

      if tenant.db_username.present? && tenant.db_password.present?
        cfg[:username] = tenant.db_username
        cfg[:password] = tenant.db_password
      end

      [ tenant_key, cfg ]
    end
  end
end
