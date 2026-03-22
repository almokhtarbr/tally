class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :url
      t.string :api_key, null: false
      t.string :api_secret, null: false
      t.integer :events_count, default: 0
      t.timestamps
    end

    add_index :projects, :api_key, unique: true
    add_index :projects, :api_secret, unique: true
  end
end
