class CreateMinimalSchema < ActiveRecord::Migration[8.0]
  def change
    # 1. Users table (Authentication)
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true

    # 2. Tenants table (1 Store per User Admin)
    create_table :tenants do |t|
      # ADDED type: :bigint
      t.references :user, type: :bigint, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :address

      t.timestamps
    end
    add_index :tenants, :slug, unique: true

    # 3. Categories table (Global Catalog Grouping)
    create_table :categories do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :categories, :name, unique: true

    # 4. Products table (Master Shared Catalog)
    create_table :products do |t|
      # ADDED type: :bigint
      t.references :category, type: :bigint, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :products, :name

    # 5. Product Listings table (Store-specific Prices and Stock)
    create_table :product_listings do |t|
      # ADDED type: :bigint
      t.references :tenant, type: :bigint, null: false, foreign_key: true
      t.references :product, type: :bigint, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :stock_quantity, default: 0, null: false

      t.timestamps
    end
    add_index :product_listings, [ :tenant_id, :product_id ], unique: true
  end
end
