class AddConversionSettingsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :conversion_event, :string, default: "purchase"
    add_column :projects, :avg_conversion_value, :decimal, precision: 10, scale: 2
  end
end
