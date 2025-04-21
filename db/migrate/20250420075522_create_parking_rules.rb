class CreateParkingRules < ActiveRecord::Migration[7.2]
  def change
    create_table :parking_rules do |t|
      t.references :street_section, null: false, foreign_key: true
      t.time :start_time
      t.time :end_time
      t.string :day_of_week
      t.integer :ordinal

      t.timestamps
    end
  end
end
