class PushNotificationJob
  include Sidekiq::Worker
  queue_as :push_notifications

  def perform(subscription_id, message, alert_id = nil)
    subscription = PushSubscription.find_by(id: subscription_id)
    return unless subscription

    payload = message.is_a?(String) ? message : message.to_json

    WebPush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: {
        subject: "mailto:you@example.com",
        public_key: Rails.application.credentials.webpush[:public_key],
        private_key: Rails.application.credentials.webpush[:private_key]
      }
    )

    mark_alert_sent(alert_id) if alert_id
  rescue WebPush::InvalidSubscription, WebPush::ResponseError => e
    Rails.logger.warn "Failed to send push for subscription #{subscription_id} alert #{alert_id}: #{e.class} - #{e.message}"
  end

  private

  def mark_alert_sent(alert_id)
    alert = Alert.find_by(id: alert_id)
    return unless alert
    return if alert.sent_at.present?

    alert.update!(sent: true, sent_at: Time.current)
  end
end
