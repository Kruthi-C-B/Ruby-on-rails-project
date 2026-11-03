require "yaml"

module Api
  module V1
    module Internal
      module Admin
        class TenantDataController < BaseController
          def product_references
            begin
              product_id = Integer(params.require(:product_id), 10)
              raise ArgumentError if product_id <= 0
            rescue ArgumentError, ActionController::ParameterMissing
              return render json: { errors: [ "A valid product_id is required" ] }, status: :bad_request
            end

            in_use = Tenant.all.any? do |tenant|
              TenantDatabase.switch(tenant) do
                ProductListing.exists?(product_id: product_id) ||
                  PurchaseHistory.exists?(product_id: product_id)
              end
            end

            render json: { in_use: in_use }
          end

          def audit_trail
            entries = Tenant.all.flat_map do |tenant|
              TenantDatabase.switch(tenant) do
                PaperTrail::Version
                  .where(item_type: %w[ProductListing PurchaseHistory])
                  .order(created_at: :desc)
                  .limit(200)
                  .map { |version| audit_entry(tenant, version) }
              end
            end

            render json: {
              audit_trail: entries.sort_by { |entry| entry[:date] || Time.at(0) }.reverse.first(200)
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
end
