require "rails_helper"

RSpec.describe ProjectDigest do
  let(:project) { create(:project) }
  let(:digest)  { described_class.new(project, ending: Date.current) }

  def rollup(name, date, count)
    create(:event_daily_rollup, project:, event_name: name, date:, count:)
  end

  describe "#events" do
    it "sums this week's rollups and compares to the previous week" do
      rollup("signup", 2.days.ago.to_date, 10)
      rollup("signup", 9.days.ago.to_date, 4)

      expect(digest.events.current).to eq(10)
      expect(digest.events.previous).to eq(4)
      expect(digest.events.pct).to eq(150) # (10-4)/4
    end

    it "pct is nil when the previous week had nothing" do
      rollup("signup", 1.day.ago.to_date, 5)
      expect(digest.events.pct).to be_nil
    end
  end

  describe "#top_events" do
    it "ranks event names by total count in the window" do
      rollup("signup", 1.day.ago.to_date, 3)
      rollup("signup", 3.days.ago.to_date, 2)
      rollup("page_view", 1.day.ago.to_date, 4)

      expect(digest.top_events(5)).to eq([ [ "signup", 5 ], [ "page_view", 4 ] ])
    end
  end

  describe "#active_users and #new_users" do
    it "counts distinct user_profile_ids with events this week" do
      p1 = create(:user_profile, project:)
      p2 = create(:user_profile, project:)
      create(:event, project:, user_profile: p1, occurred_at: 1.day.ago)
      create(:event, project:, user_profile: p2, occurred_at: 2.days.ago)
      create(:event, project:, user_profile: p1, occurred_at: 10.days.ago)

      expect(digest.active_users.current).to eq(2)
    end

    it "counts user profiles created in the window" do
      create(:user_profile, project:, created_at: 2.days.ago)
      create(:user_profile, project:, created_at: 20.days.ago)
      expect(digest.new_users).to eq(1)
    end
  end

  describe "#anomalies" do
    it "returns anomalies detected in the window, newest first" do
      recent = create(:anomaly, project:, detected_at: 1.day.ago)
      create(:anomaly, project:, detected_at: 30.days.ago)
      expect(digest.anomalies.to_a).to eq([ recent ])
    end
  end
end
