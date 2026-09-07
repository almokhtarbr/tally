# Reduces a saved report to one headline number (and a daily series for a
# sparkline) for a dashboard widget. Only the count-shaped report types
# (event explorer / trend) collapse to a single figure; funnels and
# retention return nil and the card links out.
class WidgetMetric
  DEFAULT_DAYS = 30
  SYSTEM_EVENTS = ProjectsController::SYSTEM_EVENTS

  Result = Struct.new(:value, :label, :series, keyword_init: true)

  def initialize(saved_report, days: DEFAULT_DAYS)
    @report = saved_report
    @days = days
  end

  def call
    return unless %w[event_explorer trend].include?(@report.report_type)

    event_name = @report.configuration["event_name"].presence
    by_day = scoped_rollups(event_name).group(:date).sum(:count)

    Result.new(
      value: by_day.values.sum,
      label: "#{event_name || 'events'} · last #{@days}d",
      series: zero_filled(by_day)
    )
  end

  private

  def scoped_rollups(event_name)
    rollups = @report.project.event_daily_rollups.where(date: start_date..Date.current)
    if event_name
      rollups.where(event_name: event_name)
    else
      rollups.where.not(event_name: SYSTEM_EVENTS)
    end
  end

  def start_date
    @days.days.ago.to_date
  end

  # One entry per day across the window, oldest first, missing days as 0.
  def zero_filled(by_day)
    (start_date..Date.current).map { |d| by_day[d].to_i }
  end
end
