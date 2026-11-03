class Cart < ApplicationRecord
  belongs_to :discount, optional: true
end
