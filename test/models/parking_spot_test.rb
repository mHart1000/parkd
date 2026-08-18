require "test_helper"

class ParkingSpotTest < ActiveSupport::TestCase
  setup do
    @factory = RGeo::Geographic.spherical_factory(srid: 4326)
  end

  test "geographic Point round trips with SRID 4326 and longitude latitude ordering" do
    spot = users(:one).parking_spots.create!(
      geometry: @factory.point(-122.4194, 37.7749),
      active: true
    ).reload

    assert_equal 4326, spot.geometry.srid
    assert_equal [ -122.4194, 37.7749 ], spot.geometry.coordinates
    assert_match "geography", ParkingSpot.columns_hash.fetch("geometry").sql_type
  end

  test "nearby query returns only the current user's sections within fifteen metres" do
    spot = users(:one).parking_spots.create!(
      geometry: @factory.point(-122.4194, 37.7749),
      active: true
    )

    near = users(:one).street_sections.create!(
      geometry: @factory.line_string([
        @factory.point(-122.41945, 37.77485),
        @factory.point(-122.41935, 37.77495)
      ])
    )
    users(:one).street_sections.create!(
      geometry: @factory.line_string([
        @factory.point(-122.42, 37.78),
        @factory.point(-122.421, 37.781)
      ])
    )
    users(:two).street_sections.create!(
      geometry: @factory.line_string([
        @factory.point(-122.41945, 37.77485),
        @factory.point(-122.41935, 37.77495)
      ])
    )

    assert_equal [ near.id ], spot.nearby_street_sections(users(:one)).pluck(:id)
  end
end
