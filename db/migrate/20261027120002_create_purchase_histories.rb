class CreatePurchaseHistories < ActiveRecord::Migration[8.1]
  def change
    add_column :carts, :purchase_reference, :string
    add_index :carts, :purchase_reference, unique: true

    create_table :purchase_histories do |t|
      t.bigint :user_id, null: false
      t.bigint :product_listing_id, null: false
      t.bigint :product_id, null: false
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.string :purchase_reference, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :purchased_at
      t.timestamps
    end

    add_index :purchase_histories, :user_id
    add_index :purchase_histories, :product_id
    add_index :purchase_histories, [ :purchase_reference, :product_listing_id ], unique: true,
              name: "index_purchase_histories_on_reference_and_listing"
  end
end
