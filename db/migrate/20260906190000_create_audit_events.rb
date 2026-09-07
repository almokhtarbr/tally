class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false
      t.string :summary, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :project_id, :created_at ]
  end
end
