require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "up endpoint reports a healthy application" do
    get rails_health_check_path

    assert_response :success
    assert_equal "text/html", response.media_type
  end
end
