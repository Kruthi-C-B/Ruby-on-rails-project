module LocalFindPramata
  module TenantDatabaseName
    def apartment_tenant_name
      raise ArgumentError, "Tenant must be persisted before its database can be named" unless persisted?

      "localfind_tenant_#{id}"
    end
  end
end
