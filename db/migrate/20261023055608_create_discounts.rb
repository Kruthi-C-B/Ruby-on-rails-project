class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.string :code
      t.decimal :percentage, precision: 5, scale: 2

      t.timestamps
    end
  end
end
