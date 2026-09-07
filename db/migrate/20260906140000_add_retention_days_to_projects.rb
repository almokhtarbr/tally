class AddRetentionDaysToProjects < ActiveRecord::Migration[8.1]
  def change
    # nil = keep events as long as the global partition policy allows.
    # A positive integer prunes this project's events past that many days.
    add_column :projects, :retention_days, :integer
  end
end
