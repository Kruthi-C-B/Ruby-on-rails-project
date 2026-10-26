class User < ApplicationRecord
  has_secure_password
  has_one :tenant, dependent: :destroy
  has_many :carts, dependent: :destroy

  has_many :login_audits, dependent: :destroy
end
