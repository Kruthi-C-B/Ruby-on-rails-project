class Tenant < ApplicationRecord
  belongs_to :user
  has_many :listing_references, dependent: :destroy

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-zA-Z]+\z/ }

  def apartment_tenant_name
    raise ArgumentError, "Tenant must be persisted before its database can be named" unless persisted?

    "localfind_tenant_#{id}"
  end
end
