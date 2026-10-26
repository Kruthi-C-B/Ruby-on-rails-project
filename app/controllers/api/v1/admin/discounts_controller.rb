class Api::V1::Admin::DiscountsController < Api::V1::Admin::BaseController
  def create
    discount = Discount.new(discount_params)
    if discount.save
      render json: discount, status: :created
    else
      render json: { errors: discount.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private
  def discount_params
    params.require(:discount).permit(:code, :percentage)
  end
end
