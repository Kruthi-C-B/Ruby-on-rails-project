require "yaml"

module Api
  module V1
    module Admin
      class PlatformController < ::Admin::BaseController
        def users
          render json: User.includes(:tenant).order(:id).map do |user|
            {
              id: user.id,
              email: user.email,
              role: user.is_admin? ? "Platform Admin" : (user.tenant.present? ? "Store Owner" : "Shopper"),
              created_at: user.created_at.strftime("%Y-%m-%d")
            }
          end
        end

        def stores
          render json: Tenant.includes(:user).order(:id).map do |tenant|
            {
              id: tenant.id,
              name: tenant.name,
              owner_email: tenant.user.email,
              created_at: tenant.created_at.strftime("%Y-%m-%d")
            }
          end
        end

        def audit_trail
          entries = Tenant.all.flat_map do |tenant|
            Apartment::Tenant.switch(tenant.slug) do
              PaperTrail::Version
                .where(item_type: %w[ProductListing PurchaseHistory])
                .order(created_at: :desc)
                .limit(200)
                .map { |version| audit_entry(tenant, version) }
            end
          end

          render json: { audit_trail: entries.sort_by { |entry| entry[:date] || Time.at(0) }.reverse.first(200) }
        end

        def cart_metrics
          render json: {
            total_carts: Cart.count,
            pending_carts: Cart.where(status: "pending").count,
            completed_carts: Cart.where(status: "completed").count
          }
        end

        private

        def audit_entry(tenant, version)
          changes = safe_yaml(version.object_changes)
          object = safe_yaml(version.object)
          product_id = changes.dig("product_id", 1) || object["product_id"] || changes.dig("product_id", 0)
          unit_price = changes["unit_price"]

          {
            id: "#{tenant.id}-#{version.id}",
            date: version.created_at,
            event: version.event,
            actor: User.find_by(id: version.whodunnit)&.email || "User ##{version.whodunnit || 'unknown'}",
            store_name: tenant.name,
            product_name: Product.find_by(id: product_id)&.name || "Deleted product",
            price_before: changes.dig("price", 0) || unit_price&.first,
            price_after: changes.dig("price", 1) || unit_price&.last,
            stock_before: changes.dig("stock_quantity", 0),
            stock_after: changes.dig("stock_quantity", 1)
          }
        end

        def safe_yaml(value)
          return {} if value.blank?

          YAML.safe_load(
            value,
            permitted_classes: [ BigDecimal, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone ],
            aliases: true
          ) || {}
        end
      end
    end
  end
end
