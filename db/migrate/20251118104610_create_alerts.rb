class CreateAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :parking_spot, null: false, foreign_key: true
      t.references :parking_rule, null: false, foreign_key: true
      t.datetime :alert_time
      t.boolean :sent

      t.timestamps
    end
  end
end
