class CreateLoginAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :login_audits do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.datetime :login_timestamp

      t.timestamps
    end
  end
end
