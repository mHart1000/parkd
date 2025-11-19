class PushSubscription < ApplicationRecord
  validates :endpoint, presence: true, uniqueness: true
  belongs_to :user
end
