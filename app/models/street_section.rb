class StreetSection < ApplicationRecord
  belongs_to :user
  has_many :parking_rules, dependent: :destroy
  accepts_nested_attributes_for :parking_rules, allow_destroy: true

end
