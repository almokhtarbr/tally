class DashboardWidget < ApplicationRecord
  belongs_to :dashboard
  belongs_to :saved_report

  delegate :project, to: :dashboard

  RANGE_OPTIONS = [ 7, 30, 90 ].freeze
  DEFAULT_DAYS = 30

  validates :range_days, inclusion: { in: RANGE_OPTIONS }

  # A single headline number for the widget card, or nil when the report
  # type doesn't reduce to one (funnels/retention link out instead).
  def metric
    @metric ||= WidgetMetric.new(saved_report, days: range_days).call
  end
end
