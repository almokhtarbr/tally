class CreateIdentityAliases < ActiveRecord::Migration[8.0]
  def change
    create_table :identity_aliases do |t|
      t.references :project, null: false, foreign_key: true
      t.string :anonymous_id, null: false
      t.references :user_profile, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :identity_aliases, [:project_id, :anonymous_id], unique: true
  end
end
