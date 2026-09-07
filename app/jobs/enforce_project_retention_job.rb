# Per-project retention: for projects that set a `retention_days` shorter than
# the global partition drop, delete their old events and the matching daily
# rollups. Scoped by project_id, so it rides the (project_id, name,
# occurred_at) index. Runs daily.
class EnforceProjectRetentionJob < ApplicationJob
  queue_as :default

  def perform(today: Date.current)
    Project.where.not(retention_days: nil).where("retention_days > 0").find_each do |project|
      cutoff  = today - project.retention_days
      deleted = project.events.where(occurred_at: ...cutoff.beginning_of_day).delete_all
      project.event_daily_rollups.where(date: ...cutoff).delete_all
      Rails.logger.info("[retention] #{project.name}: pruned #{deleted} events older than #{project.retention_days}d") if deleted.positive?
    end
  end
end
