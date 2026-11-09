require "active_support/concern"

module LocalFindShared
  module CatalogCategoryRules
    extend ActiveSupport::Concern

    included do
      has_many :products
      validates :name, presence: true, uniqueness: { case_sensitive: false }
    end
  end

  module CatalogProductRules
    extend ActiveSupport::Concern

    included do
      belongs_to :category
      has_many :listing_references
    end
  end

  module CatalogDiscountRules
    extend ActiveSupport::Concern

    included do
      has_many :carts
      validates :code, presence: true, uniqueness: { case_sensitive: false }
      validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
    end
  end
end
