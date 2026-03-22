class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :role, null: false, default: "member"
      t.timestamps
    end

    add_index :users, :email, unique: true

    create_table :project_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string :role, null: false, default: "viewer"
      t.timestamps
    end

    add_index :project_memberships, [:user_id, :project_id], unique: true
  end
end
