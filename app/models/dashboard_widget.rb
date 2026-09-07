class DashboardWidget < ApplicationRecord
  belongs_to :dashboard
  belongs_to :saved_report

  delegate :project, to: :dashboard

  # A single headline number for the widget card, or nil when the report
  # type doesn't reduce to one (funnels/retention link out instead).
  def metric
    @metric ||= WidgetMetric.new(saved_report).call
  end
end
