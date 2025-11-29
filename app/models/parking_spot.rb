class ParkingSpot < ApplicationRecord
  belongs_to :user
  has_many :alerts

  def nearby_street_sections(user)
    lng, lat = geometry.coordinates
    radius_m = 15.0

    StreetSection
      .where(<<~SQL.squish, lng, lat, radius_m)
        ST_DWithin(
          ST_SetSRID(ST_MakeValid(street_sections.geometry::geometry), 4326)::geography,
          ST_SetSRID(ST_Point(?, ?), 4326)::geography,
          ?
        )
      SQL
      .where(user_id: user.id)
      .includes(:parking_rules)
      .distinct
  end

  def active_rules(user)
    street_sections = nearby_street_sections(user)
    street_sections.flat_map(&:parking_rules)
  end

  def upcoming_broken_rules(user)
    active_rules(user).select do |rule|
      real_start, _real_end = rule.next_occurrence
      real_start <= Time.current + user.notification_lead_time
    end
  end
end
