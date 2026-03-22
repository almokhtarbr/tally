class CreateSavedReports < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_reports do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :report_type, null: false
      t.jsonb :configuration, null: false, default: {}
      t.timestamps
    end

    add_index :saved_reports, [:project_id, :report_type]
  end
end
