require "test_helper"

class Api::ParkingRulesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_parking_rules_index_url
    assert_response :success
  end

  test "should get create" do
    get api_parking_rules_create_url
    assert_response :success
  end

  test "should get show" do
    get api_parking_rules_show_url
    assert_response :success
  end

  test "should get update" do
    get api_parking_rules_update_url
    assert_response :success
  end

  test "should get destroy" do
    get api_parking_rules_destroy_url
    assert_response :success
  end
end
