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

  def scan_user(user)
    #lead_time = user.notification_lead_time || 12.hours
    lead_time = 12.hours
    now = Time.current

    user.parking_spots.where(active: true).find_each do |spot|
      next unless spot.geometry

      candidate_sections = nearby_street_sections(spot, user)

      candidate_sections.each do |section|
        section.parking_rules.each do |rule|
          schedule_alert_for_rule(user, spot, rule, now, lead_time)
        end
      end
    end
  end

  def nearby_street_sections(spot, user)
    lng, lat = spot.geometry.coordinates
    radius_m = 15.0

    StreetSection
      .where(<<~SQL.squish, lng, lat, radius_m)
        ST_DWithin(
          ST_SetSRID(ST_MakeValid(street_sections.geometry::geometry), 4326)::geography,
          ST_SetSRID(ST_Point(?, ?), 4326)::geography,
          ?
        )
      SQL
      .where(user_id: user.id)
      .includes(:parking_rules)
      .distinct
  end

  def schedule_alert_for_rule(user, spot, rule, now, lead_time)
    real_start, real_end = rule.next_occurrence(now)

    return unless real_start <= now + lead_time

    return if Alert.exists?(
      user_id: user.id,
      parking_spot_id: spot.id,
      parking_rule_id: rule.id,
      rule_start_time: real_start,
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


  def alert_notifier(alert)

    return if alert.sent_at.present?

    PushNotificationJob.perform_async(
      alert.user.push_subscriptions[0].id,
      "Your parking rule starts in 12 hours!"
    )

    alert.update!(sent_at: Time.current)
  end


  def deliver_due_alerts
    now = Time.current

    Alert.where("alert_time <= ?", now)
         .where(sent: false)
         .find_each do |alert|

      alert_notifier(alert)
      alert.update!(sent: true)
    end
  end
end
