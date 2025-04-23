class AddSpatialColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :street_sections, :geometry, :st_polygon, geographic: true
    add_column :parking_spots, :geometry, :st_point, geographic: true
  end
end
