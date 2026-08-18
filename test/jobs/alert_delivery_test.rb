require "test_helper"
require "sidekiq/testing"

class AlertDeliveryTest < ActiveSupport::TestCase
  WEBPUSH_CREDENTIALS = {
    public_key: "test-public-key",
    private_key: "test-private-key"
  }.freeze

  setup do
    Sidekiq::Testing.fake!
    PushNotificationJob.clear
  end

  teardown do
    PushNotificationJob.clear
  end

  test "rule scan creates one alert for each rule occurrence" do
    travel_to Time.local(2026, 8, 10, 9) do
      user, spot, rule = spatial_rule_fixture
      worker = RuleViolationAlertJob.new

      assert_difference -> { Alert.count }, 1 do
        worker.send(:scan_user, user)
      end
      assert_no_difference -> { Alert.count } do
        worker.send(:scan_user, user)
      end

      alert = Alert.order(:id).last
      assert_equal spot, alert.parking_spot
      assert_equal rule, alert.parking_rule
      assert_equal Time.local(2026, 8, 10, 10), alert.rule_start_time
      refute alert.sent
    end
  end

  test "due alert is enqueued once and records enqueue separately from delivery" do
    user, spot, rule = spatial_rule_fixture
    subscription = user.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscription",
      p256dh_key: "public-key",
      auth_key: "auth-key"
    )
    alert = Alert.create!(
      user: user,
      parking_spot: spot,
      parking_rule: rule,
      rule_start_time: 1.hour.from_now,
      alert_time: 1.minute.ago,
      sent: false
    )

    assert_difference -> { PushNotificationJob.jobs.size }, 1 do
      RuleViolationAlertJob.new.send(:deliver_due_alerts)
    end
    assert_no_difference -> { PushNotificationJob.jobs.size } do
      RuleViolationAlertJob.new.send(:deliver_due_alerts)
    end

    alert.reload
    assert alert.enqueued_at
    assert_nil alert.sent_at
    assert_equal subscription.id, PushNotificationJob.jobs.first.fetch("args").first
  end

  test "successful Web Push marks the alert sent" do
    alert, subscription = delivery_fixture
    payload = nil

    with_webpush_credentials do
      WebPush.stub(:payload_send, ->(**options) { payload = options }) do
        PushNotificationJob.new.perform(subscription.id, { "title" => "Parkd" }, alert.id)
      end
    end

    alert.reload
    assert alert.sent
    assert alert.sent_at
    assert_equal subscription.endpoint, payload.fetch(:endpoint)
    assert_equal({ "title" => "Parkd" }.to_json, payload.fetch(:message))
    assert_equal WEBPUSH_CREDENTIALS, payload.fetch(:vapid).slice(:public_key, :private_key)
  end

  test "recoverable Web Push failure leaves the alert unsent" do
    alert, subscription = delivery_fixture
    response = Struct.new(:body).new("gone")
    error = WebPush::InvalidSubscription.new(response, "push.example.test")

    with_webpush_credentials do
      WebPush.stub(:payload_send, ->(**) { raise error }) do
        assert_nothing_raised do
          PushNotificationJob.new.perform(subscription.id, { "title" => "Parkd" }, alert.id)
        end
      end
    end

    alert.reload
    refute alert.sent
    assert_nil alert.sent_at
  end

  private

  def with_webpush_credentials(&block)
    Rails.application.credentials.stub(:webpush, WEBPUSH_CREDENTIALS, &block)
  end

  def spatial_rule_fixture
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    user = users(:one)
    spot = user.parking_spots.create!(geometry: factory.point(-122.4194, 37.7749), active: true)
    section = user.street_sections.create!(
      geometry: factory.line_string([
        factory.point(-122.41945, 37.77485),
        factory.point(-122.41935, 37.77495)
      ])
    )
    rule = section.parking_rules.create!(
      start_time: "10:00:00",
      end_time: "11:00:00"
    )

    [ user, spot, rule ]
  end

  def delivery_fixture
    user, spot, rule = spatial_rule_fixture
    subscription = user.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscription",
      p256dh_key: "public-key",
      auth_key: "auth-key"
    )
    alert = Alert.create!(
      user: user,
      parking_spot: spot,
      parking_rule: rule,
      rule_start_time: 1.hour.from_now,
      alert_time: 1.minute.ago,
      sent: false,
      enqueued_at: Time.current
    )

    [ alert, subscription ]
  end
end
