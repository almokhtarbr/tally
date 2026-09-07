# Records a change to a project's configuration on its audit log. Failures
# to write the log never break the request that triggered them.
module Auditable
  extend ActiveSupport::Concern

  private

  def audit!(project, action, summary, **metadata)
    project.audit_events.create!(
      user: current_user,
      action: action,
      summary: summary,
      metadata: metadata
    )
  rescue => e
    Rails.logger.error("[audit] #{action} failed: #{e.class} #{e.message}")
  end
end
