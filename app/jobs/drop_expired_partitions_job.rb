# O(1) data retention: drop whole `events` month partitions once they fall
# outside EVENTS_RETENTION_MONTHS. No row scan, no vacuum churn — the point of
# partitioning by month. Disabled (no-op) unless EVENTS_RETENTION_MONTHS is a
# positive integer. Runs daily after PartitionMaintenanceJob.
class DropExpiredPartitionsJob < ApplicationJob
  queue_as :default

  PARTITION_RE = /\Aevents_y(\d{4})m(\d{2})\z/

  def perform(months: retention_months, today: Date.current)
    return if months <= 0

    cutoff = (today << months).beginning_of_month
    expired_partitions(cutoff).each do |name|
      connection.execute("DROP TABLE IF EXISTS #{connection.quote_table_name(name)}")
      Rails.logger.info("[retention] dropped #{name} (older than #{months} months)")
    end
  end

  # Names of month partitions whose whole range ends on or before `cutoff`.
  def expired_partitions(cutoff)
    month_partitions.filter_map do |name|
      y, m = name.match(PARTITION_RE).captures.map(&:to_i)
      range_end = Date.new(y, m, 1).next_month
      name if range_end <= cutoff
    end
  end

  private

  def month_partitions
    connection.select_values(<<~SQL).grep(PARTITION_RE)
      SELECT c.relname
      FROM pg_inherits i
      JOIN pg_class c    ON c.oid = i.inhrelid
      JOIN pg_class p    ON p.oid = i.inhparent
      WHERE p.relname = 'events'
    SQL
  end

  def connection = ActiveRecord::Base.connection

  def retention_months = ENV.fetch("EVENTS_RETENTION_MONTHS", 0).to_i
end
