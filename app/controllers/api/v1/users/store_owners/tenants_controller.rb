
module Api
  module V1
    module Users
      module StoreOwners
        class TenantsController < ApplicationController
          skip_before_action :verify_authenticity_token
          before_action :require_login

          def create
            tenant = current_user.build_tenant(tenant_params)

            if tenant.save
              TenantDatabase.provision!(tenant)
              render json: {
                message: "Store profile created successfully!",
                tenant: tenant
              }, status: :created
            else
              render json: {
                errors: tenant.errors.full_messages
              }, status: :unprocessable_entity
            end
          rescue Apartment::ApartmentError, ActiveRecord::ActiveRecordError => error
            tenant&.destroy
            Rails.logger.error("Tenant database provisioning failed: #{error.message}")
            render json: {
              errors: [ "Unable to initialize the store database." ]
            }, status: :unprocessable_entity
          end

          def update
            tenant = current_user.tenant

            unless tenant
              render json: { error: "Store profile not found" },
                     status: :not_found
              return
            end

            if tenant.update(tenant_params)
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

          def tenant_params
            params.require(:tenant).permit(:name, :slug, :address)
          end

          def require_login
            unless current_user
              render json: { error: "Not logged in" },
                     status: :unauthorized
            end
          end
        end
      end
    end
  end
end
