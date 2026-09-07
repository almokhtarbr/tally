class AddWeeklyDigestToProjectMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :project_memberships, :weekly_digest, :boolean, null: false, default: true
  end
end
