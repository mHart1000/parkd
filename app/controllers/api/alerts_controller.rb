class Api::AlertsController < ApplicationController
  before_action :authenticate_user!

  def nearby_upcoming_rules
    spot = current_user.parking_spots.find_by(active: true)
    return render json: { alert: false } unless spot&.geometry

    now = Time.now.getlocal
    tomorrow = now + 24.hours
    radius_m = 15.0

    spot_coords = spot.geometry.coordinates
    lng = spot_coords[0]
    lat = spot_coords[1]

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
        rule_day = rule.day_of_week
        rule_start_time = rule.start_time
        rule_end_time = rule.end_time

        if rule_day
          next unless [ now.strftime("%A"), tomorrow.strftime("%A") ].include?(rule_day)
        end

        rule_date = rule_day == now.strftime("%A") ? now.to_date : now.to_date + 1
        scheduled_start = Time.local(
          rule_date.year, rule_date.month, rule_date.day,
          rule_start_time.hour, rule_start_time.min, rule_start_time.sec
        )
        scheduled_end = Time.local(
          rule_date.year, rule_date.month, rule_date.day,
          rule_end_time.hour, rule_end_time.min, rule_end_time.sec
        )

        if scheduled_end <= scheduled_start
          scheduled_end += 1.day
        end

        (scheduled_start.between?(now, tomorrow) || scheduled_end.between?(now, tomorrow))
      end
    end

    render json: { alert: close_section }
  end
end
