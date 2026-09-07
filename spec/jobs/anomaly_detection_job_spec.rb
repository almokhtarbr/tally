require "rails_helper"

RSpec.describe AnomalyDetectionJob, type: :job do
  let(:project) { create(:project) }

  describe "#perform" do
    it "creates an anomaly when z_score exceeds threshold" do
      # Create 7 days of data with small variance
      counts = [ 9, 11, 10, 12, 10, 11, 9 ]
      counts.each_with_index do |c, i|
        create(:event_daily_rollup, project: project, event_name: "signup", date: (i + 1).days.ago.to_date, count: c)
      end
      # Today: spike to 50
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 50)

      expect { described_class.new.perform }.to change(Anomaly, :count).by(1)

      anomaly = Anomaly.last
      expect(anomaly.event_name).to eq("signup")
      expect(anomaly.anomaly_type).to eq("spike")
      expect(anomaly.actual_value).to eq(50.0)
      expect(anomaly.severity).to be_present
    end

    it "creates a drop anomaly when count is much lower than average" do
      counts = [ 98, 102, 100, 105, 97, 103, 99 ]
      counts.each_with_index do |c, i|
        create(:event_daily_rollup, project: project, event_name: "purchase", date: (i + 1).days.ago.to_date, count: c)
      end
      create(:event_daily_rollup, project: project, event_name: "purchase", date: Date.current, count: 5)

      expect { described_class.new.perform }.to change(Anomaly, :count).by(1)

      anomaly = Anomaly.last
      expect(anomaly.anomaly_type).to eq("drop")
    end

    it "does not create anomaly when within normal range" do
      counts = [ 9, 11, 10, 12, 10, 11, 9 ]
      counts.each_with_index do |c, i|
        create(:event_daily_rollup, project: project, event_name: "signup", date: (i + 1).days.ago.to_date, count: c)
      end
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 11)

      expect { described_class.new.perform }.not_to change(Anomaly, :count)
    end

    it "does not create duplicate active anomalies" do
      counts = [ 9, 11, 10, 12, 10, 11, 9 ]
      counts.each_with_index do |c, i|
        create(:event_daily_rollup, project: project, event_name: "signup", date: (i + 1).days.ago.to_date, count: c)
      end
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 50)

      described_class.new.perform
      expect { described_class.new.perform }.not_to change(Anomaly, :count)
    end

    it "resolves stale anomalies that returned to normal" do
      anomaly = create(:anomaly, project: project, event_name: "signup", detected_at: 2.days.ago)

      counts = [ 9, 11, 10, 12, 10, 11, 9 ]
      counts.each_with_index do |c, i|
        create(:event_daily_rollup, project: project, event_name: "signup", date: (i + 1).days.ago.to_date, count: c)
      end
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 10)

      described_class.new.perform
      expect(anomaly.reload.resolved_at).to be_present
    end

    it "fires webhooks on anomaly detection" do
      webhook = create(:webhook, project: project, event_names: [ "*" ])
      counts = [ 9, 11, 10, 12, 10, 11, 9 ]
      counts.each_with_index do |c, i|
        create(:event_daily_rollup, project: project, event_name: "signup", date: (i + 1).days.ago.to_date, count: c)
      end
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 50)

      expect { described_class.new.perform }.to have_enqueued_job(WebhookDeliveryJob)
    end
  end
end
