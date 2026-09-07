class AddDefaultEventsPartition < ActiveRecord::Migration[8.1]
  # The original migration created month partitions for a fixed window
  # (2026-02..2026-05). Anything outside it raises CheckViolation. A DEFAULT
  # partition is the safety net: rows always land somewhere, and the monthly
  # partitions PartitionMaintenanceJob adds still give us pruning/vacuum wins
  # for the hot ranges.
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS events_default PARTITION OF events DEFAULT;
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS events_default;"
  end
end
