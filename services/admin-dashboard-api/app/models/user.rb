class User < ApplicationRecord
  include LocalFindShared::AdminRole

  has_one :tenant
end
