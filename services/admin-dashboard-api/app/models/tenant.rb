class Tenant < ApplicationRecord
  belongs_to :user
  has_many :listing_references

  def database_tenant_name
    "localfind_tenant_#{id}"
  end
end
