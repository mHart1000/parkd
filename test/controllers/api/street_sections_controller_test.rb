require "test_helper"

class Api::StreetSectionsControllerTest < ActionDispatch::IntegrationTest
  test "authentication is required" do
    get api_street_sections_path, as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Invalid credentials" }, JSON.parse(response.body))
  end

  test "creates a LineString without changing longitude latitude ordering" do
    token = sign_in_token

    assert_difference -> { users(:one).street_sections.count }, 1 do
      post api_street_sections_path,
        params: {
          street_section: {
            geometry: {
              type: "LineString",
              coordinates: [ [ -122.4194, 37.7749 ], [ -122.4193, 37.7750 ] ]
            },
            side_of_street: "right"
          }
        },
        headers: bearer_headers(token),
        as: :json
    end

    assert_response :created
    geometry = users(:one).street_sections.order(:id).last.geometry
    assert_equal 4326, geometry.srid
    assert_equal [ -122.4194, 37.7749 ], geometry.point_n(0).coordinates
    assert_equal [ -122.4193, 37.775 ], geometry.point_n(1).coordinates
  end

  test "rejects a one-point line with the stable 422 status" do
    token = sign_in_token

    assert_no_difference -> { users(:one).street_sections.count } do
      post api_street_sections_path,
        params: {
          street_section: {
            geometry: { type: "LineString", coordinates: [ [ -122.4194, 37.7749 ] ] }
          }
        },
        headers: bearer_headers(token),
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal 422, response.status
    assert_equal "Invalid line: must have at least 2 points", JSON.parse(response.body).fetch("error")
  end
end
