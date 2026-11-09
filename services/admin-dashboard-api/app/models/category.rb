class Category < ApplicationRecord
  include LocalFindShared::CatalogCategoryRules
end
