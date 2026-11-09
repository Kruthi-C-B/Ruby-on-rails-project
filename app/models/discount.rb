class Discount < ApplicationRecord
  include LocalFindShared::CatalogDiscountRules
end
