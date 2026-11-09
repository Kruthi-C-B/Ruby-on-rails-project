
module TenantMigrations
  class CreateProductListings
    def self.up(connection)
      connection.create_table(
        :product_listings,
        if_not_exists: true,
        options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci"
      ) do |t|
        t.bigint :product_id, null: false
        t.decimal :price, precision: 10, scale: 2,
                         default: 0.0, null: false
        t.integer :stock_quantity, default: 0, null: false
        t.datetime :created_at, null: false
        t.datetime :updated_at, null: false
      end

      connection.add_index(
        :product_listings,
        :product_id,
        name: "index_product_listings_on_product_id",
        if_not_exists: true
      )
    end
  end
end
