class SavedReport < ApplicationRecord
  belongs_to :project

  validates :name, presence: true
  validates :report_type, presence: true, inclusion: { in: %w[funnel retention event_explorer trend] }
  validates :configuration, presence: true

  scope :by_type, ->(type) { where(report_type: type) }
  scope :recent, -> { order(updated_at: :desc) }

  def to_query_params
    configuration.merge("report_id" => id)
  end
end
