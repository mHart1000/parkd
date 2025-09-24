class ChangeStreetSectionGeometryToLineString < ActiveRecord::Migration[7.2]
  def change
    remove_column :street_sections, :geometry

    add_column :street_sections, :geometry, :geometry, limit: { type: "LineString", srid: 4326 }
  end
end
