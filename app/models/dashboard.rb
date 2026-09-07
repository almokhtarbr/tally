class Dashboard < ApplicationRecord
  belongs_to :project

  has_many :dashboard_widgets, -> { order(:position) }, dependent: :destroy
  has_many :saved_reports, through: :dashboard_widgets

  validates :name, presence: true

  scope :recent, -> { order(:created_at) }

  # Add a saved report as the next widget on this board. Ignores a report
  # that's already pinned here so the board stays a set.
  def pin(saved_report, range_days: DashboardWidget::DEFAULT_DAYS)
    return if dashboard_widgets.exists?(saved_report_id: saved_report.id)

    next_position = (dashboard_widgets.maximum(:position) || -1) + 1
    dashboard_widgets.create!(saved_report: saved_report, position: next_position, range_days: range_days)
  end
end
