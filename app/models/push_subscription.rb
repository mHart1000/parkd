class PushSubscription < ApplicationRecord
  validates :endpoint, presence: true, uniqueness: true
end
