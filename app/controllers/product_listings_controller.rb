# class ProductListingsController < ApplicationController
#   before_action :require_login
#   before_action :ensure_tenant_exists

#   def index
#     @listings = current_user.tenant.product_listings.includes(:product)
#   end

#   def new
#     @listing = current_user.tenant.product_listings.build
#     @products = Product.all
#   end

#   def create
#     @listing = current_user.tenant.product_listings.build(listing_params)
#     if @listing.save
#       redirect_to product_listings_path, notice: "Product added to store listing!"
#     else
#       @products = Product.all
#       render :new, status: :unprocessable_entity
#     end
#   end

#   def edit
#     @listing = current_user.tenant.product_listings.find(params[:id])
#   end

#   def update
#     @listing = current_user.tenant.product_listings.find(params[:id])
#     if @listing.update(listing_params)
#       redirect_to product_listings_path, notice: "Listing updated successfully!"
#     else
#       render :edit, status: :unprocessable_entity
#     end
#   end

#   def destroy
#     @listing = current_user.tenant.product_listings.find(params[:id])
#     @listing.destroy
#     redirect_to product_listings_path, notice: "Listing removed from store."
#   end

#   private

#   def ensure_tenant_exists
#     redirect_to new_tenant_path, alert: "Please create a store profile first." unless current_user.tenant
#   end

#   def listing_params
#     params.require(:product_listing).permit(:product_id, :price, :stock_quantity)
#   end
# end


class ProductListingsController < ApplicationController
  before_action :require_login
  before_action :ensure_tenant_exists

  # Catch database unique constraint violations as a fallback
  rescue_from ActiveRecord::RecordNotUnique, with: :handle_duplicate_listing

  def index
    @listings = current_user.tenant.product_listings.includes(:product)
  end

  def new
  @product_listing = current_user.tenant.product_listings.build

  # If the user selected a category, fetch those products. Otherwise, leave it empty.
  if params[:category_id].present?
    @products = Product.where(category_id: params[:category_id])
  else
    @products = []
  end
  end

  def create
    @listing = current_user.tenant.product_listings.build(listing_params)
    if @listing.save
      redirect_to product_listings_path, notice: "Product added to store listing!"
    else
      @products = Product.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @listing = current_user.tenant.product_listings.find(params[:id])
  end

  def update
    @listing = current_user.tenant.product_listings.find(params[:id])
    if @listing.update(listing_params)
      redirect_to product_listings_path, notice: "Listing updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing = current_user.tenant.product_listings.find(params[:id])
    @listing.destroy
    redirect_to product_listings_path, notice: "Listing removed from store."
  end

  private

  def ensure_tenant_exists
    redirect_to new_tenant_path, alert: "Please create a store profile first." unless current_user.tenant
  end

  def listing_params
    params.require(:product_listing).permit(:product_id, :price, :stock_quantity)
  end

  def handle_duplicate_listing
    @listing = current_user.tenant.product_listings.build(listing_params)
    @listing.errors.add(:product_id, "is already listed in your store. Please edit the existing listing instead.")
    @products = Product.all
    render :new, status: :unprocessable_entity
  end
end
