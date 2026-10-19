class TenantsController < ApplicationController
  before_action :require_login

  def new
    @tenant = current_user.build_tenant
  end

  def create
    @tenant = current_user.build_tenant(tenant_params)
    if @tenant.save
      redirect_to product_listings_path, notice: "Store profile created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tenant = current_user.tenant
  end

  def update
    @tenant = current_user.tenant
    if @tenant.update(tenant_params)
      redirect_to product_listings_path, notice: "Store profile updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def tenant_params
    params.require(:tenant).permit(:name, :slug, :address)
  end
end
