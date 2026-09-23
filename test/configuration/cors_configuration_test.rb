require "test_helper"

class CorsConfigurationTest < ActionDispatch::IntegrationTest
  ALLOWED_ORIGIN = ENV.fetch("CLIENT_URL")

  test "configured origin can preflight an authenticated API request" do
    options api_user_path, headers: {
      "Origin" => ALLOWED_ORIGIN,
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "Authorization, Content-Type"
    }

    assert_response :ok
    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_equal "true", response.headers["Access-Control-Allow-Credentials"]
    assert_includes response.headers.fetch("Access-Control-Allow-Methods"), "GET"
    assert_includes response.headers.fetch("Access-Control-Allow-Headers").downcase, "authorization"
    assert_includes response.headers.fetch("Access-Control-Allow-Headers").downcase, "content-type"
  end

  test "authentication failure remains readable to the configured origin" do
    get api_user_path, headers: { "Origin" => ALLOWED_ORIGIN }, as: :json

    assert_response :unauthorized
    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_equal "true", response.headers["Access-Control-Allow-Credentials"]
  end

  test "unconfigured origin receives no CORS permission headers" do
    options api_user_path, headers: {
      "Origin" => "https://untrusted.example.test",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "Authorization"
    }

    assert_nil response.headers["Access-Control-Allow-Origin"]
    assert_nil response.headers["Access-Control-Allow-Credentials"]
  end
end
