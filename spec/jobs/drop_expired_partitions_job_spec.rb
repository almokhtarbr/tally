require "rails_helper"

RSpec.describe DropExpiredPartitionsJob, type: :job do
  subject(:job) { described_class.new }

  def conn = ActiveRecord::Base.connection

  def make_partition(name, from, to)
    conn.execute("CREATE TABLE IF NOT EXISTS #{name} PARTITION OF events FOR VALUES FROM ('#{from}') TO ('#{to}')")
  end

  def drop_partition(name)
    conn.execute("DROP TABLE IF EXISTS #{name}")
  end

  describe "#expired_partitions" do
    it "returns month partitions whose range ends on or before the cutoff" do
      # The base migration ships events_y2026m02..m05.
      cutoff = Date.new(2026, 4, 1)
      expect(job.expired_partitions(cutoff)).to contain_exactly("events_y2026m02", "events_y2026m03")
    end

    it "keeps a partition that ends after the cutoff" do
      expect(job.expired_partitions(Date.new(2026, 3, 1))).to contain_exactly("events_y2026m02")
    end

    it "ignores events_default" do
      expect(job.expired_partitions(Date.new(2030, 1, 1))).not_to include("events_default")
    end
  end

  describe "#perform" do
    it "no-ops when retention is not configured" do
      expect { job.perform(months: 0) }.not_to change { job.send(:month_partitions).size }
    end

    it "drops a partition that has aged out, keeps a recent one" do
      make_partition("events_y2019m01", "2019-01-01", "2019-02-01")
      make_partition("events_y2099m01", "2099-01-01", "2099-02-01")

      job.perform(months: 6, today: Date.new(2026, 9, 1))

      names = job.send(:month_partitions)
      expect(names).not_to include("events_y2019m01")
      expect(names).to include("events_y2099m01")
    ensure
      drop_partition("events_y2019m01")
      drop_partition("events_y2099m01")
    end
  end
end
