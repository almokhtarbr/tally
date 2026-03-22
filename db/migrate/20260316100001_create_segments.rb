class CreateSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :segments do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.jsonb :conditions, null: false, default: []
      t.timestamps
    end

    add_index :segments, [:project_id, :name], unique: true
  end
end
