# class ProductListing < TenantRecord
#   has_paper_trail versions: {
#   class_name: "TenantVersion"
# }
#   belongs_to :product

#   validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
#   validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

#   validates :product_id, uniqueness: {
#     message: "is already listed in your store. Please edit the existing listing instead."
#   }
# end


class ProductListing < TenantRecord
  has_paper_trail versions: {
    class_name: "TenantVersion"
  }

  belongs_to :product

  attr_readonly :product_id

  validates :price,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :stock_quantity,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  validates :product_id,
            uniqueness: {
              message: "is already listed in your store. Please edit the existing listing instead."
            }
end