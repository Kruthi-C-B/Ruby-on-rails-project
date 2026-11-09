class TenantVersion < TenantRecord
  include PaperTrail::VersionConcern

  self.table_name = "versions"
end
