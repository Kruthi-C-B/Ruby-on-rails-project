class AddEmailToLoginAudits < ActiveRecord::Migration[8.1]
  def change
    add_column :login_audits, :email, :string
  end
end
