class PartitionMaintenanceJob < ApplicationJob
  queue_as :default

  def perform
    (0..2).each do |months_ahead|
      date = months_ahead.months.from_now.beginning_of_month
      partition_name = "events_y#{date.year}m#{date.strftime('%m')}"
      next_month = date + 1.month

      begin
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS #{partition_name} PARTITION OF events
            FOR VALUES FROM ('#{date.strftime('%Y-%m-%d')}') TO ('#{next_month.strftime('%Y-%m-%d')}');
        SQL
        Rails.logger.info("Partition #{partition_name} ensured")
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.info("Partition #{partition_name} already exists: #{e.message}")
      end
    end
  end
end
