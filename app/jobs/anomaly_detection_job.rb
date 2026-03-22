class AnomalyDetectionJob < ApplicationJob
  queue_as :default

  LOOKBACK_DAYS = 7
  DEFAULT_THRESHOLD = 2.5

  def perform
    Project.find_each do |project|
      detect_anomalies(project)
    end
  end

  private

  def detect_anomalies(project)
    event_names = project.event_daily_rollups
      .where(date: LOOKBACK_DAYS.days.ago.to_date..1.day.ago.to_date)
      .distinct.pluck(:event_name)

    event_names.each do |event_name|
      check_event(project, event_name)
    end

    resolve_stale_anomalies(project)
  end

  def check_event(project, event_name)
    daily_counts = project.event_daily_rollups
      .where(event_name: event_name, date: LOOKBACK_DAYS.days.ago.to_date..1.day.ago.to_date)
      .pluck(:date, :count)
      .to_h

    return if daily_counts.size < 3

    values = daily_counts.values
    mean = values.sum.to_f / values.size
    variance = values.map { |c| (c - mean)**2 }.sum / values.size
    stddev = Math.sqrt(variance)

    today_count = project.event_daily_rollups
      .where(event_name: event_name, date: Date.current)
      .sum(:count)

    z_score = stddev > 0 ? (today_count - mean) / stddev : 0

    if z_score.abs > DEFAULT_THRESHOLD
      anomaly_type = if today_count == 0 && mean > 1
        "absence"
      elsif today_count > mean
        "spike"
      else
        "drop"
      end

      severity = Anomaly.severity_for_z_score(z_score)

      existing = project.anomalies.active
        .where(event_name: event_name)
        .where("detected_at > ?", 24.hours.ago)
        .first

      unless existing
        anomaly = project.anomalies.create!(
          event_name: event_name,
          anomaly_type: anomaly_type,
          expected_value: mean,
          actual_value: today_count,
          z_score: z_score,
          severity: severity,
          detected_at: Time.current
        )

        fire_anomaly_webhooks(project, anomaly)
      end
    end
  end

  def resolve_stale_anomalies(project)
    project.anomalies.active.where("detected_at < ?", 24.hours.ago).find_each do |anomaly|
      recent_count = project.event_daily_rollups
        .where(event_name: anomaly.event_name, date: Date.current)
        .sum(:count)

      daily_counts = project.event_daily_rollups
        .where(event_name: anomaly.event_name, date: LOOKBACK_DAYS.days.ago.to_date..1.day.ago.to_date)
        .pluck(:count)

      next if daily_counts.size < 3

      mean = daily_counts.sum.to_f / daily_counts.size
      variance = daily_counts.map { |c| (c - mean)**2 }.sum / daily_counts.size
      stddev = Math.sqrt(variance)

      z_score = stddev > 0 ? (recent_count - mean) / stddev : 0

      anomaly.resolve! if z_score.abs <= DEFAULT_THRESHOLD
    end
  end

  def fire_anomaly_webhooks(project, anomaly)
    payload = {
      type: "anomaly",
      event_name: anomaly.event_name,
      anomaly_type: anomaly.anomaly_type,
      expected: anomaly.expected_value.round(1),
      actual: anomaly.actual_value.round(1),
      severity: anomaly.severity,
      detected_at: anomaly.detected_at.iso8601
    }

    project.webhooks.active.each do |webhook|
      next unless webhook.matches_event?("anomaly") || webhook.matches_event?("*")
      WebhookDeliveryJob.perform_later(
        webhook_id: webhook.id,
        event_name: "anomaly",
        payload: payload
      )
    end
  rescue => e
    Rails.logger.warn("[Tally] Anomaly webhook dispatch failed: #{e.message}")
  end
end
