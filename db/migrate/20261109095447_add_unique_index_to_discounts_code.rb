class AddUniqueIndexToDiscountsCode < ActiveRecord::Migration[8.1]
  def change
    change_column_null :discounts, :code, false
    change_column_null :discounts, :percentage, false

    add_index :discounts, :code, unique: true
  end
end