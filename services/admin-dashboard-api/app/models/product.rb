class Product < ApplicationRecord
  has_paper_trail
  include LocalFindPramata::CatalogProductRules
end
