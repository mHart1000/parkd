class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :street_sections
  has_many :parking_rules, through: :street_sections
  has_many :parking_spots
  has_many :push_subscriptions
  has_many :alerts

  ALLOWED_NOTIFICATION_LEAD_TIME_HOURS = [ 1, 3, 6, 12, 24 ].freeze

  validates :notification_lead_time_hours,
            inclusion: { in: ALLOWED_NOTIFICATION_LEAD_TIME_HOURS },
            allow_nil: true

  def notification_lead_time
    hours = notification_lead_time_hours || 12
    hours.hours
  end
end
