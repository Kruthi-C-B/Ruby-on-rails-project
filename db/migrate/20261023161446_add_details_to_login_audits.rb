class AddDetailsToLoginAudits < ActiveRecord::Migration[8.1]
  def change
    add_column :login_audits, :status, :string
    add_column :login_audits, :failure_reason, :string
  end
end
