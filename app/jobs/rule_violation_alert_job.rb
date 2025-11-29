class RuleViolationAlertJob
  include Sidekiq::Worker

  sidekiq_options queue: :push_notifications

  def perform
    User.find_each do |user|
      scan_user(user)
    end

    deliver_due_alerts
  end

  private

  # If we ever need to scale, geometric querying and alert creation can
  # be done in jobs triggered by after_commit callbacks on ParkingSpot
  # and ParkingRule. This job could pretty much just be deliver_due_alerts

  def scan_user(user)
    # lead_time = user.notification_lead_time || 12.hours
    lead_time = 12.hours
    now = Time.current

    user.parking_spots.where(active: true).find_each do |spot|
      next unless spot.geometry

      active_rules = spot.active_rules(user)

      active_rules.each do |rule|
        schedule_alert_for_rule(user, spot, rule, now, lead_time)
      end
    end
  end

  def schedule_alert_for_rule(user, spot, rule, now, lead_time)
    real_start, real_end = rule.next_occurrence(now)

    return unless real_start <= now + lead_time

    return if Alert.exists?(
      user_id: user.id,
      parking_spot_id: spot.id,
      parking_rule_id: rule.id,
      rule_start_time: real_start
    )

    alert_time = real_start - lead_time

    Alert.create!(
      user: user,
      parking_spot: spot,
      parking_rule: rule,
      rule_start_time: real_start,
      alert_time: alert_time,
      sent: false
    )
  end

  def deliver_due_alerts
    Alert.ready_to_send.find_each do |alert|
      enqueue_alert_notification(alert)
    end
  end

  def enqueue_alert_notification(alert)
    user = alert.user
    return unless user
    # lead_time = user.notification_lead_time || 12.hours
    lead_time = 12.hours

    subscription = user.push_subscriptions.first
    return unless subscription

    message = {
      "title" => "Parkd",
      "body" => "Your parking rule starts in #{lead_time / 1.hour} hours!"
    }

    PushNotificationJob.perform_async(
      subscription.id,
      message,
      alert.id
    )

    alert.update!(enqueued_at: Time.current)
  end
end
