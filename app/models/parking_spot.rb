class ParkingSpot < ApplicationRecord
  belongs_to :user
  has_many :alerts
end
