class Api::AlertsController < ApplicationController
  before_action :authenticate_user!

  def nearby_upcoming_rules
    spot = current_user.parking_spots.find_by(active: true)
    return render json: { alert: false } unless spot&.geometry

    now = Time.now.getlocal
    tomorrow = now + 24.hours
    radius_m = 15.0

    lng, lat = spot.geometry.coordinates

    candidate_sections = StreetSection
      .where(
        <<~SQL.squish, lng, lat, radius_m
          ST_DWithin(
            ST_SetSRID(ST_MakeValid(street_sections.geometry::geometry), 4326)::geography,
            ST_SetSRID(ST_Point(?, ?), 4326)::geography,
            ?
          )
        SQL
      )
      .where(user_id: current_user.id)
      .includes(:parking_rules)
      .distinct

    close_section = candidate_sections.any? do |section|
      section.parking_rules.any? do |rule|
        start_dt, end_dt = rule.next_occurrence(now)

        start_in_window  = start_dt.between?(now, tomorrow)
        end_in_window = end_dt.between?(now, tomorrow)

        start_in_window || end_in_window
      end
    end

    render json: { alert: close_section }
  end
end
