class AddProvisioningStatusToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :provisioning_status,
               :string, default: "pending", null: false

    add_column :tenants, :provisioning_error, :text

    add_column :tenants, :provisioning_started_at, :datetime

    add_column :tenants, :provisioned_at, :datetime

    add_column :tenants, :provisioning_attempts,
               :integer, default: 0, null: false

    add_index :tenants, :provisioning_status
  end
end