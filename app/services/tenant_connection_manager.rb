class TenantConnectionManager
  ROLE = :writing

  class << self
    def with_tenant(tenant, &block)
      shard = shard_name(tenant)

      Rails.logger.info "========== TENANT CONNECTION DEBUG =========="
  Rails.logger.info "Tenant ID: #{tenant.id}"
  Rails.logger.info "Shard: #{shard}"

      register_tenant_connection!(tenant, shard)

      TenantRecord.connected_to(
        role: ROLE,
        shard: shard,
        &block
      )
    end

    def register_tenant_connection!(tenant, shard = shard_name(tenant))
      return if registered?(shard)

      config = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup

      config[:database] = TenantDatabase.database_name_for(tenant)
      config[:username] = tenant.db_username
      config[:password] = tenant.db_password

      raise "Tenant DB username is missing" if tenant.db_username.blank?
      raise "Tenant DB password is missing" if tenant.db_password.blank?

      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
        Rails.env,
        "tenant_#{tenant.id}",
        config
      )

      TenantRecord.connection_handler.establish_connection(
        db_config,
        owner_name: TenantRecord,
        role: ROLE,
        shard: shard
      )

      TenantRecord.instance_variable_set(
  :@shard_keys,
  (TenantRecord.shard_keys + [ shard ]).uniq
)
    end

    def registered?(shard)
      TenantRecord.connection_handler.retrieve_connection_pool(
        TenantRecord,
        role: ROLE,
        shard: shard,
        strict: false
      ).present?
    end

    private

    def shard_name(tenant)
       :"tenant_#{tenant.id}"
    end
  end
end
