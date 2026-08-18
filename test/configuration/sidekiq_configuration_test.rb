require "test_helper"
require "yaml"

class SidekiqConfigurationTest < ActiveSupport::TestCase
  test "alert scan cadence and queue stay aligned" do
    schedule = YAML.safe_load_file(Rails.root.join("config/schedule.yml"))
    job = schedule.fetch("rule_violation_alert_job")
    queues = YAML.safe_load_file(
      Rails.root.join("config/sidekiq.yml"),
      permitted_classes: [ Symbol ],
      aliases: true
    ).fetch(:queues)

    assert_equal "*/5 * * * *", job.fetch("cron")
    assert_equal "RuleViolationAlertJob", job.fetch("class")
    assert_equal "push_notifications", job.fetch("queue")
    assert_includes queues, "push_notifications"
    assert_equal "push_notifications", RuleViolationAlertJob.get_sidekiq_options.fetch("queue").to_s
    assert_equal "push_notifications", PushNotificationJob.get_sidekiq_options.fetch("queue").to_s
  end

  test "Sidekiq Web remains mounted with cookie session middleware" do
    route_paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
    middleware = Rails.application.config.middleware.map(&:klass)

    assert route_paths.any? { |path| path.start_with?("/sidekiq") }
    assert_includes middleware, ActionDispatch::Cookies
    assert_includes middleware, ActionDispatch::Session::CookieStore
  end
end
