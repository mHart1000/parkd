class AddAdditionalFieldsToParkingRules < ActiveRecord::Migration[7.2]
  def change
    add_column :parking_rules, :start_date, :date
    add_column :parking_rules, :end_date, :date
    add_column :parking_rules, :day_of_month, :integer
    add_column :parking_rules, :even_odd, :string
  end
end
