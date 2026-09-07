# Reduces a saved report to one headline number for a dashboard widget.
# Only the count-shaped report types (event explorer / trend) collapse to a
# single figure; funnels and retention return nil and the card links out.
class WidgetMetric
  DEFAULT_DAYS = 30
  SYSTEM_EVENTS = ProjectsController::SYSTEM_EVENTS

  Result = Struct.new(:value, :label, keyword_init: true)

  def initialize(saved_report, days: DEFAULT_DAYS)
    @report = saved_report
    @days = days
  end

  def call
    return unless %w[event_explorer trend].include?(@report.report_type)

    rollups = @report.project.event_daily_rollups.where(date: @days.days.ago.to_date..Date.current)

    event_name = @report.configuration["event_name"].presence
    rollups = if event_name
      rollups.where(event_name: event_name)
    else
      rollups.where.not(event_name: SYSTEM_EVENTS)
    end

    Result.new(
      value: rollups.sum(:count),
      label: "#{event_name || 'events'} · last #{@days}d"
    )
  end
end
