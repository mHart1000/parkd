class ChangeOrdinalToJsonbInParkingRules < ActiveRecord::Migration[7.2]
  def change
    remove_column :parking_rules, :ordinal, :integer
    add_column :parking_rules, :ordinal, :jsonb
  end
end
