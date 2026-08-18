require "test_helper"

class Api::UsersAuthenticationTest < ActionDispatch::IntegrationTest
  test "registers a user with the existing response shape" do
    assert_difference -> { User.count }, 1 do
      post user_registration_path,
        params: {
          user: {
            name: "New User",
            email: "new-user@example.com",
            password: "Password3!",
            password_confirmation: "Password3!"
          }
        },
        as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "User created successfully.", body.fetch("message")
    assert_equal "new-user@example.com", body.dig("user", "email")
    assert_equal "New User", body.dig("user", "name")
    assert_equal %w[email id name], body.fetch("user").keys.sort
  end

  test "rejects invalid registration with the stable 422 status" do
    assert_no_difference -> { User.count } do
      post user_registration_path,
        params: {
          user: {
            email: "invalid@example.com",
            password: "Password3!",
            password_confirmation: "different"
          }
        },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal 422, response.status
    assert JSON.parse(response.body).fetch("errors").any?
  end

  test "signs in, returns a bearer token, and preserves user serialization" do
    token = sign_in_token
    sign_in_body = JSON.parse(response.body)

    assert token.present?
    assert_equal users(:one).email, sign_in_body.dig("user", "email")

    get api_user_path, headers: bearer_headers(token), as: :json

    assert_response :ok
    assert_equal(
      {
        "id" => users(:one).id,
        "name" => "One User",
        "email" => "one@example.com",
        "notification_lead_time_hours" => 12
      },
      JSON.parse(response.body)
    )
  end

  test "rejects invalid credentials" do
    post user_session_path,
      params: { user: { email: users(:one).email, password: "wrong-password" } },
      as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Invalid credentials" }, JSON.parse(response.body))
  end

  test "logout revokes the issued token" do
    user = users(:one)
    original_jti = user.jti
    token = sign_in_token(user)

    delete destroy_user_session_path, headers: bearer_headers(token), as: :json

    assert_response :no_content
    refute_equal original_jti, user.reload.jti

    get api_user_path, headers: bearer_headers(token), as: :json
    assert_response :unauthorized
  end

  test "parsed JSON preserves characters affected by Rails 8.1 escaping defaults" do
    raw_name = "A <tag> & separator\u2028paragraph\u2029"
    users(:one).update!(name: raw_name)
    token = sign_in_token

    get api_user_path, headers: bearer_headers(token), as: :json

    assert_response :ok
    assert_equal raw_name, JSON.parse(response.body).fetch("name")
  end

  test "invalid preference updates keep the stable error contract" do
    token = sign_in_token

    patch api_user_path,
      params: { user: { notification_lead_time_hours: 2 } },
      headers: bearer_headers(token),
      as: :json

    assert_response :unprocessable_content
    assert_equal 422, response.status
    assert_match "Notification lead time hours", JSON.parse(response.body).fetch("error")
  end
end
