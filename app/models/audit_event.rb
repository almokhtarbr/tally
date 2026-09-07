# An append-only record of a change to a project's configuration — who did
# it, what changed, and when. Written through the Auditable concern.
class AuditEvent < ApplicationRecord
  belongs_to :project
  belongs_to :user, optional: true

  validates :action, :summary, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Name to show for the actor, tolerant of a since-deleted user.
  def actor_name
    user&.name || "System"
  end
end
