require "rails_helper"

RSpec.describe Event, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it "requires a name" do
      event = Event.new(project: project, name: nil, occurred_at: Time.current)
      expect(event).not_to be_valid
    end

    it "requires occurred_at" do
      event = Event.new(project: project, name: "test", occurred_at: nil)
      expect(event).not_to be_valid
    end
  end

  describe "scopes" do
    it ".chronological orders by occurred_at descending" do
      old = create(:event, project: project, occurred_at: 2.days.ago)
      new_ev = create(:event, project: project, occurred_at: 1.hour.ago)
      expect(project.events.chronological.first).to eq(new_ev)
    end

    it ".for_date_range filters by occurred_at" do
      create(:event, project: project, occurred_at: 10.days.ago)
      recent = create(:event, project: project, occurred_at: 1.day.ago)
      results = project.events.for_date_range(3.days.ago, Time.current)
      expect(results).to include(recent)
    end
  end
end
