class User < ApplicationRecord
  has_one :tenant
  has_many :carts

  def is_admin?
    is_admin || platform_admin
  end
end
