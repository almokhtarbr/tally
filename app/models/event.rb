class Event < ApplicationRecord
  self.primary_key = :id

  belongs_to :project
  belongs_to :user_profile, optional: true

  validates :name, presence: true
  validates :occurred_at, presence: true

  scope :chronological, -> { order(occurred_at: :desc) }
  scope :for_date_range, ->(from, to) { where(occurred_at: from..to) }
end
