class Api::AlertsController < ApplicationController
  before_action :authenticate_user!

  def nearby_upcoming_rules
    spot = current_user.parking_spots.find_by(active: true)
    return render json: { alert: false } unless spot&.geometry

    now = Time.now.getlocal
    tomorrow = now + 24.hours

    radius_m = 12.0 # was ~6.1m; a bit more tolerant for GPS + drawing error

    # Approach: buffer the spot point (geography) and intersect with section geometry (geography).
    candidate_sections = StreetSection
      .joins(:parking_rules)
      .where(parking_rules: { day_of_week: [now.strftime('%A'), tomorrow.strftime('%A')] })
      .where(
        <<~SQL.squish,
          ST_Intersects(
            street_sections.geometry::geography,
            ST_Buffer(ST_GeomFromText(?, 4326)::geography, ?)
          )
        SQL
        spot.geometry.as_text,
        radius_m
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
        rule_start_time = rule.start_time
        rule_end_time = rule.end_time

        next unless [now.strftime('%A'), tomorrow.strftime('%A')].include?(rule_day)

        rule_date = rule_day == now.strftime('%A') ? now.to_date : now.to_date + 1
        scheduled_start = Time.local(
          rule_date.year, rule_date.month, rule_date.day,
          rule_start_time.hour, rule_start_time.min, rule_start_time.sec
        )
        scheduled_end = Time.local(
          rule_date.year, rule_date.month, rule_date.day,
          rule_end_time.hour, rule_end_time.min, rule_end_time.sec
        )

        Rails.logger.debug "############# ALERTS DEBUG  #2 ##########"
        Rails.logger.debug "rule: #{rule.inspect}"
        Rails.logger.debug "rule_day: #{rule_day}"
        Rails.logger.debug "start_rule_time: #{rule_start_time}"
        Rails.logger.debug "end_rule_time: #{rule_end_time}"
        Rails.logger.debug "rule_date: #{rule_date}"
        Rails.logger.debug "Scheduled start: #{scheduled_start}"
        Rails.logger.debug "Scheduled end: #{scheduled_end}"
        Rails.logger.debug "Now: #{now}"
        Rails.logger.debug "Tomorrow: #{tomorrow}"
        Rails.logger.debug "Scheduled start between now and tomorrow: #{scheduled_start.between?(now, tomorrow)}"
        Rails.logger.debug "Scheduled end between now and tomorrow: #{scheduled_end.between?(now, tomorrow)}"
        Rails.logger.debug "############# ALERTS DEBUG  #2 ##########"
        (scheduled_start.between?(now, tomorrow) || scheduled_end.between?(now, tomorrow))
      end
    end

    render json: { alert: close_section }
  end
end
