class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.references :project, null: false, foreign_key: true
      t.string :url, null: false
      t.jsonb :event_names, null: false, default: []
      t.string :secret
      t.boolean :active, null: false, default: true
      t.integer :failures, null: false, default: 0
      t.datetime :last_triggered_at
      t.timestamps
    end

    add_index :webhooks, [ :project_id, :active ]
  end
end
