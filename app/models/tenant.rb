class Tenant < ApplicationRecord
  include LocalFindShared::TenantDatabaseName

  encrypts :db_password

  belongs_to :user
  has_many :listing_references, dependent: :destroy

  before_validation :strip_slug_whitespace

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :db_username, format: { with: /\A[a-zA-Z0-9_]+\z/ }, allow_nil: true

  def default_db_username
    raise ArgumentError, "Tenant must be persisted before deriving database username" unless persisted?

    "tenant_#{id}_app"
  end

  def ensure_db_credentials!
    raise ArgumentError, "Tenant must be persisted before credentials can be generated" unless persisted?

    self.db_username ||= default_db_username
    self.db_password ||= SecureRandom.base58(32)
    save! if changed?
  end

  def rotate_db_password!(new_password = SecureRandom.base58(32))
    raise ArgumentError, "Tenant must be persisted before rotating credentials" unless persisted?

    update!(db_password: new_password)
  end

  private

  def strip_slug_whitespace
    self.slug = slug.strip if slug.is_a?(String)
  end
end
