class Alert < ApplicationRecord
  belongs_to :user
  belongs_to :parking_spot
  belongs_to :parking_rule
end