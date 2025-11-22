class ParkingRule < ApplicationRecord
  belongs_to :street_section
  has_many :alerts

  def next_occurrence(from_time = Time.current)
    now = from_time.getlocal
    tomorrow = now + 24.hours

    rule_day = day_of_week

    # No day_of_week means it applies every day
    if rule_day.nil?
      rule_date =
        if later_today?(now)
          now.to_date
        else
          now.to_date + 1
        end
    else
      rule_date = compute_next_rule_date(rule_day, now)
    end

    start_dt = Time.local(
      rule_date.year, rule_date.month, rule_date.day,
      start_time.hour, start_time.min, start_time.sec
    )

    end_dt = Time.local(
      rule_date.year, rule_date.month, rule_date.day,
      end_time.hour, end_time.min, end_time.sec
    )

    end_dt += 1.day if end_dt <= start_dt

    [ start_dt, end_dt ]
  end

  private

  def later_today?(now)
    candidate = now.change(
      hour: start_time.hour,
      min:  start_time.min,
      sec:  start_time.sec
    )
    candidate > now
  end

  def compute_next_rule_date(rule_day, now)
    today_str = now.strftime("%A")
    tomorrow_str = (now + 1.day).strftime("%A")

    if today_str == rule_day && later_today?(now)
      now.to_date
    elsif tomorrow_str == rule_day
      now.to_date + 1
    else
      date = now.to_date
      7.times do
        date += 1.day
        return date if date.strftime("%A") == rule_day
      end
    end
  end
end
