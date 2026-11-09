class AddDbCredentialsToTenants < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:tenants)

    add_column :tenants, :db_username, :string unless column_exists?(:tenants, :db_username)
    add_column :tenants, :db_password, :string unless column_exists?(:tenants, :db_password)
  end
end
