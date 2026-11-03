module LocalFindPramata
  module AdminRole
    def is_admin?
      !!(self[:is_admin] || self[:platform_admin])
    end
  end
end
