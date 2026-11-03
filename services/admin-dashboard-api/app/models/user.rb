class User < ApplicationRecord
  include LocalFindPramata::AdminRole

  has_one :tenant
end
