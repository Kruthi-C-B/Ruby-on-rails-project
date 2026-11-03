class Discount < ApplicationRecord
  has_paper_trail
  include LocalFindPramata::CatalogDiscountRules
end
