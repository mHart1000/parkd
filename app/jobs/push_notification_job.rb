class PushNotificationJob < ApplicationJob
  queue_as :push_notifications

  def perform(subscription_id, message)
    subscription = PushSubscription.find(subscription_id)

    WebPush.payload_send(
      message: message.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: {
        subject: "mailto:you@example.com",
        public_key: Rails.application.credentials.webpush[:public_key],
        private_key: Rails.application.credentials.webpush[:private_key]
      }
    )
  end
end
