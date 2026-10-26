class Api::V1::Admin::PlatformController < ApplicationController
  before_action :require_admin

  def users
    # Returns all users and whether they have a store or are an admin
    users = User.includes(:tenant).all.map do |user|
      {
        id: user.id,
        email: user.email,
        role: user.is_admin? ? "Platform Admin" : (user.tenant.present? ? "Store Owner" : "Shopper"),
        created_at: user.created_at.strftime("%Y-%m-%d")
      }
    end
    render json: users, status: :ok
  end

  def stores
    # Returns all stores and their owner's email
    stores = Tenant.includes(:user).all.map do |store|
      {
        id: store.id,
        name: store.name,
        owner_email: store.user.email,
        created_at: store.created_at.strftime("%Y-%m-%d")
      }
    end
    render json: stores, status: :ok
  end


  def audit_trail
  versions = PaperTrail::Version
    .where(item_type: "ProductListing")
    .order(created_at: :desc)
    .limit(200)

    audit_trail = versions.map do |version|
      listing = ProductListing.includes(:product, :tenant)
        .find_by(id: version.item_id)

      changes = version.object_changes.present? ? YAML.safe_load(
        version.object_changes,
        permitted_classes: [ BigDecimal, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone ],
        aliases: true
      ) : {}
      actor = User.find_by(id: version.whodunnit)

      {
        id: version.id,
        date: version.created_at,
        event: version.event,
        actor: actor&.email || "User ##{version.whodunnit || 'unknown'}",
        store_name: listing&.tenant&.name || "Deleted store",
        product_name: listing&.product&.name || "Deleted product",
        price_before: changes.dig("price", 0),
        price_after: changes.dig("price", 1),
        stock_before: changes.dig("stock_quantity", 0),
        stock_after: changes.dig("stock_quantity", 1)
      }
    end

  render json: { audit_trail: audit_trail }, status: :ok
  end


  private

  def require_admin
    unless current_user&.is_admin?
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end
end
