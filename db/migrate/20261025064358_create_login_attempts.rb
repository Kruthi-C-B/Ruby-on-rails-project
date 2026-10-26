class CreateLoginAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :login_attempts do |t|
      t.string :email
      t.string :ip_address
      t.string :user_agent
      t.string :status
      t.string :failure_reason
      t.datetime :login_timestamp

      t.timestamps
    end
  end
end
