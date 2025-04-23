class AddActiveToParkingSpots < ActiveRecord::Migration[7.2]
  def change
    add_column :parking_spots, :active, :boolean
  end
end
