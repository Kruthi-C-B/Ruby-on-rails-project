class Discount < ApplicationRecord
  include LocalFindPramata::CatalogDiscountRules
end
