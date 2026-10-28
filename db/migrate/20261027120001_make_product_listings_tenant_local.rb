class MakeProductListingsTenantLocal < ActiveRecord::Migration[8.1]
  def up
    execute("DELETE FROM product_listings") if Apartment::Tenant.current == Apartment::Tenant.default_tenant

    remove_foreign_key :product_listings, :tenants if foreign_key_exists?(:product_listings, :tenants)
    remove_foreign_key :product_listings, :products if foreign_key_exists?(:product_listings, :products)
    remove_index :product_listings, name: "index_product_listings_on_tenant_id_and_product_id" if
      index_exists?(:product_listings, name: "index_product_listings_on_tenant_id_and_product_id")
    remove_index :product_listings, name: "index_product_listings_on_tenant_id" if
      index_exists?(:product_listings, name: "index_product_listings_on_tenant_id")
    remove_column :product_listings, :tenant_id if column_exists?(:product_listings, :tenant_id)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Tenant-local listings cannot be restored to the shared product listings table automatically"
  end
end
