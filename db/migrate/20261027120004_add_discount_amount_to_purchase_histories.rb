class AddDiscountAmountToPurchaseHistories < ActiveRecord::Migration[8.1]
  def change
    add_column :purchase_histories, :discount_amount, :decimal, precision: 10, scale: 2,
               null: false, default: 0
  end
end
