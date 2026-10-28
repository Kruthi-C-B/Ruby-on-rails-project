class Api::V1::Admin::DiscountsController < Api::V1::Admin::BaseController
  def index
    discounts = Discount.order(:id)
    render json: discounts
  end

  def create
    discount = Discount.new(discount_params)
    if discount.save
      render json: discount,
      status: :created
    else
      render json: { errors: discount.errors.full_messages },
                    status: :unprocessable_entity
    end
  end

  def update
    discount = Discount.find(params[:id])
    if discount.update(discount_params)
      render json: discount, status: :ok
    else
      render json: { errors: discount.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def destroy
    discount = Discount.find(params[:id])
    if discount.carts.exists?
      return render json: {
        errors: [ "Cannot delete a discount that is applied to carts." ]
      }, status: :unprocessable_entity
    end

    discount.destroy!
    render json: { message: "Discount deleted." }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Discount not found." ] }, status: :not_found
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => error
    render json: { errors: [ error.message ] }, status: :unprocessable_entity
  end

  private

  def discount_params
    params.require(:discount).permit(:code, :percentage)
  end
end
