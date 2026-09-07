class CreateDashboards < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboards do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :dashboard_widgets do |t|
      t.references :dashboard, null: false, foreign_key: true
      t.references :saved_report, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :dashboard_widgets, [ :dashboard_id, :position ]
  end
end
