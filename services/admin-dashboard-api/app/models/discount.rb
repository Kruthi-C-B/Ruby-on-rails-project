class Discount < ApplicationRecord
  has_paper_trail
  include LocalFindShared::CatalogDiscountRules
end
