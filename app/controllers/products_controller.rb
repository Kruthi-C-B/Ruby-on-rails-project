class ProductsController < ApplicationController
  # GET /
  # GET /products
  def index
    @categories = Category.all

    # Only fetch products that exist in the product_listings table
    @products = Product.joins(:product_listings).includes(:category).distinct

    # Search filter
    if params[:query].present?
      # Specify 'products.name' to prevent table ambiguity errors
      @products = @products.where("products.name LIKE ?", "%#{params[:query]}%")
    end

    # Category filter
    if params[:category_id].present?
      @products = @products.where(category_id: params[:category_id])
    end
  end

  # GET /products/:id
  def show
    @product = Product.find(params[:id])
    @listings = @product.product_listings.includes(:tenant)
  end
end
