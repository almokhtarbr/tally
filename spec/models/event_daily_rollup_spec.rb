require "rails_helper"

RSpec.describe EventDailyRollup, type: :model do
  let(:project) { create(:project) }

  describe ".increment!" do
    it "creates a new rollup if none exists" do
      expect {
        EventDailyRollup.increment!(project.id, "signup", Date.current)
      }.to change(EventDailyRollup, :count).by(1)

      rollup = EventDailyRollup.last
      expect(rollup.count).to eq(1)
      expect(rollup.event_name).to eq("signup")
    end

    it "increments existing rollup atomically" do
      EventDailyRollup.increment!(project.id, "signup", Date.current)
      EventDailyRollup.increment!(project.id, "signup", Date.current)

      rollup = EventDailyRollup.find_by(project_id: project.id, event_name: "signup", date: Date.current)
      expect(rollup.count).to eq(2)
    end

    it "keeps separate rollups for different events" do
      EventDailyRollup.increment!(project.id, "signup", Date.current)
      EventDailyRollup.increment!(project.id, "purchase", Date.current)

      expect(EventDailyRollup.count).to eq(2)
    end

    it "keeps separate rollups for different dates" do
      EventDailyRollup.increment!(project.id, "signup", Date.current)
      EventDailyRollup.increment!(project.id, "signup", Date.yesterday)

      expect(EventDailyRollup.count).to eq(2)
    end
  end
end
