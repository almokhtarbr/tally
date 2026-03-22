class CreateEvents < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      CREATE TABLE events (
        id bigserial NOT NULL,
        project_id bigint NOT NULL,
        user_profile_id bigint,
        name varchar NOT NULL,
        properties jsonb DEFAULT '{}' NOT NULL,
        idempotency_key varchar,
        occurred_at timestamp NOT NULL,
        created_at timestamp NOT NULL DEFAULT NOW(),
        PRIMARY KEY (id, occurred_at)
      ) PARTITION BY RANGE (occurred_at);

      -- Create partitions: previous month, current month, and next 2 months
      CREATE TABLE events_y2026m02 PARTITION OF events
        FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
      CREATE TABLE events_y2026m03 PARTITION OF events
        FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
      CREATE TABLE events_y2026m04 PARTITION OF events
        FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
      CREATE TABLE events_y2026m05 PARTITION OF events
        FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

      -- Indexes
      CREATE INDEX idx_events_project_name_time ON events (project_id, name, occurred_at);
      CREATE INDEX idx_events_project_user_time ON events (project_id, user_profile_id, occurred_at);
      CREATE INDEX idx_events_properties ON events USING GIN (properties);

      -- Partial unique index for idempotency (no bloat for events without keys)
      CREATE UNIQUE INDEX idx_events_idempotency ON events (project_id, idempotency_key, occurred_at)
        WHERE idempotency_key IS NOT NULL;

      -- Foreign keys (applied to partitioned table)
      ALTER TABLE events ADD CONSTRAINT fk_events_project
        FOREIGN KEY (project_id) REFERENCES projects(id);
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS events CASCADE;"
  end
end
