class Api::V1::DiscountsController < Api::V1::BaseController
  skip_before_action :require_api_login!

  def index
    # Returns only the code and percentage so shoppers know what to type
    discounts = Discount.select(:id, :code, :percentage).to_a.uniq(&:code)
    render json: discounts, status: :ok
  end
end
