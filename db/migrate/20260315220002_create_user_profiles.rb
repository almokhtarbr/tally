class CreateUserProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_profiles do |t|
      t.references :project, null: false, foreign_key: true
      t.string :external_id, null: false
      t.jsonb :properties, default: {}
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.timestamps
    end

    add_index :user_profiles, [:project_id, :external_id], unique: true
  end
end
