class AddRangeDaysToDashboardWidgets < ActiveRecord::Migration[8.1]
  def change
    add_column :dashboard_widgets, :range_days, :integer, null: false, default: 30
  end
end
