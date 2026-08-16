require "test_helper"

class ParkingRuleTest < ActiveSupport::TestCase
  test "daily rule later today uses the same day" do
    start_at, end_at = rule(start_hour: 10, end_hour: 11).next_occurrence(Time.local(2026, 8, 10, 9))

    assert_equal Time.local(2026, 8, 10, 10), start_at
    assert_equal Time.local(2026, 8, 10, 11), end_at
  end

  test "daily rule after its end advances to the next day" do
    start_at, = rule(start_hour: 10, end_hour: 11).next_occurrence(Time.local(2026, 8, 10, 12))

    assert_equal Time.local(2026, 8, 11, 10), start_at
  end

  test "weekly rule finds its next named weekday" do
    start_at, = rule(start_hour: 10, end_hour: 11, day: "Friday").next_occurrence(Time.local(2026, 8, 10, 9))

    assert_equal Time.local(2026, 8, 14, 10), start_at
  end

  test "overnight rule ends on the following day" do
    start_at, end_at = rule(start_hour: 23, end_hour: 1).next_occurrence(Time.local(2026, 8, 10, 0, 30))

    assert_equal Time.local(2026, 8, 10, 23), start_at
    assert_equal Time.local(2026, 8, 11, 1), end_at
  end

  private

  def rule(start_hour:, end_hour:, day: nil)
    ParkingRule.new(
      start_time: format("%02d:00:00", start_hour),
      end_time: format("%02d:00:00", end_hour),
      day_of_week: day
    )
  end
end
