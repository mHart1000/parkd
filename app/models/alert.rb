class Alert < ApplicationRecord
  scope :ready_to_send, ->(now = Time.current) {
    where(alert_time: ..now, sent_at: nil, enqueued_at: nil)
  }

  belongs_to :user
  belongs_to :parking_spot
  belongs_to :parking_rule
end
