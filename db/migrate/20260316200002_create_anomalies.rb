class CreateAnomalies < ActiveRecord::Migration[8.0]
  def change
    create_table :anomalies do |t|
      t.references :project, null: false, foreign_key: true
      t.string :event_name, null: false
      t.string :anomaly_type, null: false
      t.float :expected_value, null: false
      t.float :actual_value, null: false
      t.float :z_score, null: false
      t.string :severity, null: false, default: "info"
      t.datetime :detected_at, null: false
      t.datetime :resolved_at
      t.boolean :acknowledged, default: false, null: false
      t.timestamps
    end

    add_index :anomalies, [ :project_id, :event_name, :detected_at ]
    add_index :anomalies, [ :project_id, :resolved_at ], where: "resolved_at IS NULL", name: "idx_anomalies_active"
  end
end
