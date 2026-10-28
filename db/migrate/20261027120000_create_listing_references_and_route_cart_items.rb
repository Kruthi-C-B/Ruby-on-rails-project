class CreateListingReferencesAndRouteCartItems < ActiveRecord::Migration[8.1]
  def up
    create_table :listing_references do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.bigint :tenant_listing_id, null: false
      t.decimal :price, precision: 10, scale: 2, null: false, default: 0
      t.integer :stock_quantity, null: false, default: 0
      t.timestamps
    end
    add_index :listing_references, [ :tenant_id, :product_id ], unique: true
    add_index :listing_references, [ :tenant_id, :tenant_listing_id ], unique: true

    add_column :cart_items, :listing_reference_id, :bigint

    migrate_legacy_listings if shared_database?
    backfill_cart_items if shared_database?

    orphaned_items = select_value("SELECT COUNT(*) FROM cart_items WHERE listing_reference_id IS NULL").to_i
    if orphaned_items.positive?
      raise ActiveRecord::MigrationError,
            "#{orphaned_items} cart items could not be mapped to a tenant listing reference"
    end

    change_column_null :cart_items, :listing_reference_id, false
    add_index :cart_items, :listing_reference_id
    add_foreign_key :cart_items, :listing_references

    remove_foreign_key :cart_items, :product_listings if foreign_key_exists?(:cart_items, :product_listings)
    remove_index :cart_items, :product_listing_id if index_exists?(:cart_items, :product_listing_id)
    remove_column :cart_items, :product_listing_id if column_exists?(:cart_items, :product_listing_id)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cart items may reference listings in separate tenant databases"
  end

  private

  def shared_database?
    Apartment::Tenant.current == Apartment::Tenant.default_tenant
  end

  def migrate_legacy_listings
    legacy_listings = select_all(
      "SELECT id, tenant_id, product_id, price, stock_quantity, created_at, updated_at FROM product_listings"
    ).to_a

    tenant_ids = legacy_listings.map { |listing| listing["tenant_id"].to_i }.uniq
    tenants = Tenant.all.index_by(&:id)
    missing_tenants = tenant_ids - tenants.keys.map(&:to_i)
    if missing_tenants.any?
      raise ActiveRecord::MigrationError,
            "Product listings reference missing tenants: #{missing_tenants.join(', ')}"
    end

    tenant_databases = select_values("SHOW DATABASES")

    tenants.each_value do |tenant|
      database_name = Apartment::Tenant.environmentify(tenant.slug)
      TenantDatabase.provision!(tenant) unless tenant_databases.include?(database_name)
    end

    legacy_listings.group_by { |listing| listing["tenant_id"].to_i }.each do |tenant_id, listings|
      tenant = tenants.fetch(tenant_id)
      Apartment::Tenant.switch(tenant.slug) do
        connection.execute("SET FOREIGN_KEY_CHECKS = 0")
        listings.each do |listing|
          connection.execute(<<~SQL.squish)
            INSERT IGNORE INTO product_listings
              (id, tenant_id, product_id, price, stock_quantity, created_at, updated_at)
            VALUES
              (#{connection.quote(listing["id"])},
               #{connection.quote(listing["tenant_id"])},
               #{connection.quote(listing["product_id"])},
               #{connection.quote(listing["price"])},
               #{connection.quote(listing["stock_quantity"])},
               #{connection.quote(listing["created_at"])},
               #{connection.quote(listing["updated_at"])})
          SQL
        end
        connection.execute("SET FOREIGN_KEY_CHECKS = 1")
      ensure
        connection.execute("SET FOREIGN_KEY_CHECKS = 1")
      end
    end

    legacy_listings.each do |listing|
      ListingReference.create!(
        tenant_id: listing["tenant_id"],
        product_id: listing["product_id"],
        tenant_listing_id: listing["id"],
        price: listing["price"],
        stock_quantity: listing["stock_quantity"],
        created_at: listing["created_at"],
        updated_at: listing["updated_at"]
      )
    end
  end

  def backfill_cart_items
    execute(<<~SQL.squish)
      UPDATE cart_items
      INNER JOIN product_listings
        ON product_listings.id = cart_items.product_listing_id
      INNER JOIN listing_references
        ON listing_references.tenant_id = product_listings.tenant_id
        AND listing_references.tenant_listing_id = product_listings.id
      SET cart_items.listing_reference_id = listing_references.id
    SQL
  end
end
