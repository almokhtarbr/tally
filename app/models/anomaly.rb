class Anomaly < ApplicationRecord
  belongs_to :project

  validates :event_name, presence: true
  validates :anomaly_type, presence: true, inclusion: { in: %w[spike drop absence] }
  validates :severity, presence: true, inclusion: { in: %w[info warning critical] }
  validates :expected_value, presence: true
  validates :actual_value, presence: true
  validates :z_score, presence: true
  validates :detected_at, presence: true

  scope :active, -> { where(resolved_at: nil) }
  scope :recent, -> { order(detected_at: :desc) }
  scope :unacknowledged, -> { where(acknowledged: false) }

  def active?
    resolved_at.nil?
  end

  def resolve!
    update!(resolved_at: Time.current)
  end

  def acknowledge!
    update!(acknowledged: true)
  end

  def change_pct
    return 0 if expected_value.zero?
    ((actual_value - expected_value) / expected_value * 100).round(1)
  end

  def description
    case anomaly_type
    when "spike"
      "#{event_name} spiked #{change_pct.abs}% above expected (#{actual_value.round} vs #{expected_value.round})"
    when "drop"
      "#{event_name} dropped #{change_pct.abs}% below expected (#{actual_value.round} vs #{expected_value.round})"
    when "absence"
      "No #{event_name} events detected (expected ~#{expected_value.round})"
    end
  end

  def self.severity_for_z_score(z)
    abs_z = z.abs
    if abs_z > 4
      "critical"
    elsif abs_z > 3
      "warning"
    else
      "info"
    end
  end
end
