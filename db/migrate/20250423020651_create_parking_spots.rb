class CreateParkingSpots < ActiveRecord::Migration[7.2]
  def change
    create_table :parking_spots do |t|
      t.jsonb :coordinates
      t.string :side_of_street
      t.jsonb :address
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
