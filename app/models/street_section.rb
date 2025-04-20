class StreetSection < ApplicationRecord
  belongs_to :user
  has_many :parking_rules, dependent: :destroy
end
