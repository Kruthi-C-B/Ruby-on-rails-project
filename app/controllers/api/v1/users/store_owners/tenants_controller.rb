
module Api
  module V1
    module Users
      module StoreOwners
        class TenantsController < Api::V1::BaseController
          skip_before_action :verify_authenticity_token

          def create
            tenant = current_user.build_tenant(create_tenant_params)

            if tenant.save
              TenantDatabase.provision_new!(tenant)
              render json: {
                message: "Store profile created successfully!",
                tenant: tenant
              }, status: :created
            else
              render json: {
                errors: tenant.errors.full_messages
              }, status: :unprocessable_entity
            end
          rescue Apartment::ApartmentError, ActiveRecord::ActiveRecordError, TenantDatabase::Error => error
            tenant&.destroy
            Rails.logger.error("Tenant database provisioning failed: #{error.message}")
            render_error("Unable to initialize the store database.", status: :unprocessable_entity)
          end

          def update
            tenant = current_user.tenant

            unless tenant
              return render_error("Store profile not found", status: :not_found)
            end

            if tenant.update(update_tenant_params)
              render json: {
                message: "Store profile updated successfully!",
                tenant: tenant
              }, status: :ok
            else
              render json: {
                errors: tenant.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          private

          def create_tenant_params
            params.require(:tenant).permit(:name, :slug, :address)
          end

          def update_tenant_params
            params.require(:tenant).permit(:name, :slug, :address)
          end
        end
      end
    end
  end
end
