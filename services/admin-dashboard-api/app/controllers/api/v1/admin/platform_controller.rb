module Api
  module V1
    module Admin
      class PlatformController < ::Admin::BaseController
        def users
          rows = User
            .left_outer_joins(:tenant)
            .select("users.id", "users.email", "users.is_admin", "users.platform_admin", "users.created_at",
                    "tenants.id AS associated_tenant_id")
            .order("users.id")
            .map do |user|
            {
              id: user.id,
              email: user.email,
              role: user.is_admin? ? "Platform Admin" : (user.associated_tenant_id.present? ? "Store Owner" : "Shopper"),
              created_at: user.created_at.strftime("%Y-%m-%d")
            }
          end
          render json: rows
        end

        def stores
          rows = Tenant
            .joins(:user)
            .select("tenants.id", "tenants.name", "tenants.created_at", "users.email AS owner_email")
            .order("tenants.id")
            .map do |tenant|
              {
                id: tenant.id,
                name: tenant.name,
                owner_email: tenant.owner_email,
                created_at: tenant.created_at.strftime("%Y-%m-%d")
              }
            end
          render json: rows
        end

        def audit_trail
          render json: MainAppInternalClient.new(authorization: request.headers["Authorization"])
            .get("/api/v1/internal/admin/audit_trail")
        rescue MainAppInternalClient::Error => error
          Rails.logger.error("Tenant audit data request failed: #{error.message}")
          render json: { errors: [ "Tenant audit data is temporarily unavailable" ] }, status: :service_unavailable
        end

        def cart_metrics
          render json: {
            total_carts: Cart.count,
            pending_carts: Cart.where(status: "pending").count,
            completed_carts: Cart.where(status: "completed").count
          }
        end

      end
    end
  end
end
