
module TenantMigrations
  class CreatePurchaseHistories
    def self.up(connection)
      connection.create_table(
        :purchase_histories,
        if_not_exists: true,
        options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci"
      ) do |t|
        t.bigint :user_id, null: false
        t.bigint :product_listing_id, null: false
        t.bigint :product_id, null: false
        t.integer :quantity, null: false
        t.decimal :unit_price, precision: 10, scale: 2, null: false
        t.decimal :total_price, precision: 10, scale: 2, null: false
        t.string :purchase_reference, null: false
        t.string :status, default: "pending", null: false
        t.datetime :purchased_at
        t.datetime :created_at, null: false
        t.datetime :updated_at, null: false
        t.decimal :discount_amount, precision: 10, scale: 2,
                                    default: 0.0, null: false
      end

      connection.add_index(
        :purchase_histories,
        :product_id,
        name: "index_purchase_histories_on_product_id",
        if_not_exists: true
      )

      connection.add_index(
        :purchase_histories,
        [ :purchase_reference, :product_listing_id ],
        unique: true,
        name: "index_purchase_histories_on_reference_and_listing",
        if_not_exists: true
      )

      connection.add_index(
        :purchase_histories,
        :user_id,
        name: "index_purchase_histories_on_user_id",
        if_not_exists: true
      )
    end
  end
end
