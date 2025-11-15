class CreatePushSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :push_subscriptions do |t|
      t.text :endpoint
      t.string :p256dh_key
      t.string :auth_key
      t.string :device_token
      t.string :platform
      t.integer :user_id

      t.timestamps
    end

    add_index :push_subscriptions, :endpoint, unique: true
    add_index :push_subscriptions, :device_token, unique: true
  end
end
