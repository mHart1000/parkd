class Api::AlertsController < ApplicationController
  before_action :authenticate_user!

  def nearby_upcoming_rules
    spot = current_user.parking_spots.find_by(active: true)
    return render json: { alert: false } unless spot&.geometry

    now = Time.zone.now
    tomorrow = now + 24.hours

    candidate_sections = StreetSection
      .joins(:parking_rules)
      .where(parking_rules: { day_of_week: [now.strftime('%A'), tomorrow.strftime('%A')] })
      .where(
        "ST_DWithin(street_sections.geometry::geography, ST_GeomFromText(?, 4326)::geography, ?)",
        spot.geometry.as_text,
        4.57 # 15 feet
      ).distinct

      Rails.logger.debug"########### ALERTS DEBUG ##########"
      Rails.logger.debug"########### ALERTS DEBUG ##########"
      Rails.logger.debug "Candidate sections: #{candidate_sections.inspect}"
    Rails.logger.debug "Spot geometry: #{spot.geometry.as_text}"
    Rails.logger.debug "Now: #{now}"
    Rails.logger.debug "Tomorrow: #{tomorrow}"
    Rails.logger.debug "Spot coordinates: #{spot.geometry.coordinates.inspect}"
      Rails.logger.debug"########### ALERTS DEBUG ##########"
      Rails.logger.debug"########### ALERTS DEBUG ##########"
    close_section = candidate_sections.any? do |section|
      section.parking_rules.any? do |rule|
        rule_day = rule.day_of_week
        rule_time = rule.start_time

        next unless [now.strftime('%A'), tomorrow.strftime('%A')].include?(rule_day)

        rule_date = rule_day == now.strftime('%A') ? now.to_date : now.to_date + 1
        scheduled_start = Time.zone.local(
          rule_date.year, rule_date.month, rule_date.day,
          rule_time.hour, rule_time.min, rule_time.sec
        )

        scheduled_start.between?(now, tomorrow)
      end
    end

    render json: { alert: close_section }
  end
end
