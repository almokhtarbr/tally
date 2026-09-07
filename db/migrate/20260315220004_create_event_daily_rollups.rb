class CreateEventDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :event_daily_rollups do |t|
      t.references :project, null: false, foreign_key: true
      t.string :event_name, null: false
      t.date :date, null: false
      t.integer :count, null: false, default: 0
      t.timestamps
    end

    add_index :event_daily_rollups, [ :project_id, :event_name, :date ], unique: true, name: 'idx_rollups_project_event_date'
  end
end
