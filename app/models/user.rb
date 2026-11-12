class User < ApplicationRecord
  include LocalFindShared::AdminRole

  has_secure_password
  has_one :tenant, dependent: :restrict_with_error
  has_many :carts, dependent: :destroy

  has_many :login_audits, dependent: :destroy
end
