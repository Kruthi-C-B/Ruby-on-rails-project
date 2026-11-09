class Product < ApplicationRecord
  has_paper_trail
  include LocalFindShared::CatalogProductRules
end
