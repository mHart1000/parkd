class ParkingRule < ApplicationRecord
  belongs_to :street_section
  has_many :alerts
end
