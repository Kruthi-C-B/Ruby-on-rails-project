class TenantRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: {
    default: {
      writing: :primary
    }
  }
end
