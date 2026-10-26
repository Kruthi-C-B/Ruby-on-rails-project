# class CartItem < ApplicationRecord
#   belongs_to :cart
#   belongs_to :product_listing
# end

class CartItem < ApplicationRecord
  has_paper_trail

  belongs_to :cart
  belongs_to :product_listing
end
