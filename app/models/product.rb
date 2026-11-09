class Product < ApplicationRecord
  include LocalFindShared::CatalogProductRules
end
