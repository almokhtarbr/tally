class AddInvitationAcceptedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :invitation_accepted_at, :datetime
    # Everyone who exists today logged in with a password an admin set, so
    # treat them as already onboarded.
    execute "UPDATE users SET invitation_accepted_at = created_at"
  end

  def down
    remove_column :users, :invitation_accepted_at
  end
end
