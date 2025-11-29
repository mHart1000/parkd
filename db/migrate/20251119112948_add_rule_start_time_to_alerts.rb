class AddRuleStartTimeToAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column :alerts, :rule_start_time, :datetime
  end
end
