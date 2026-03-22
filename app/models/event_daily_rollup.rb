class EventDailyRollup < ApplicationRecord
  belongs_to :project

  validates :event_name, presence: true
  validates :date, presence: true
  validates :event_name, uniqueness: { scope: [:project_id, :date] }

  def self.increment!(project_id, event_name, date)
    upsert(
      { project_id: project_id, event_name: event_name, date: date, count: 1 },
      unique_by: [:project_id, :event_name, :date],
      on_duplicate: Arel.sql("count = event_daily_rollups.count + 1")
    )
  end
end
