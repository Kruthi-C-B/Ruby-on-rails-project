class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :discount, null: true, foreign_key: true
      t.string :status, default: "pending"

      t.timestamps
    end
  end
end
