class Api::AlertsController < Api::ApiController

  def nearby_upcoming_rules
    spot = current_user.parking_spots.find_by(active: true)
    return render json: { alert: false } unless spot&.geometry

    now = Time.now.getlocal
    tomorrow = now + 24.hours

    close_section = spot.active_rules(current_user).any? do |rule|
      start_dt, end_dt = rule.next_occurrence(now)

      start_in_window  = start_dt.between?(now, tomorrow)
      end_in_window = end_dt.between?(now, tomorrow)

      start_in_window || end_in_window
    end

    render json: { alert: close_section }
  end
end
