require "rails_helper"

RSpec.describe Segment, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it "requires a name" do
      segment = Segment.new(project: project, name: nil, conditions: [])
      expect(segment).not_to be_valid
    end

    it "enforces unique name per project" do
      create(:segment, project: project, name: "VIPs")
      dup = build(:segment, project: project, name: "VIPs")
      expect(dup).not_to be_valid
    end
  end

  describe "#matching_user_ids" do
    it "returns users who did a specific event" do
      user1 = create(:user_profile, project: project)
      user2 = create(:user_profile, project: project)
      create(:event, project: project, user_profile: user1, name: "purchase", occurred_at: 1.day.ago)

      segment = create(:segment, project: project, conditions: [
        { "type" => "event", "event" => "purchase", "operator" => "did", "days" => 30 }
      ])

      expect(segment.matching_user_ids).to include(user1.id)
      expect(segment.matching_user_ids).not_to include(user2.id)
    end

    it "returns users who did NOT do a specific event" do
      user1 = create(:user_profile, project: project)
      user2 = create(:user_profile, project: project)
      create(:event, project: project, user_profile: user1, name: "purchase", occurred_at: 1.day.ago)

      segment = create(:segment, project: project, conditions: [
        { "type" => "event", "event" => "purchase", "operator" => "did_not" }
      ])

      expect(segment.matching_user_ids).not_to include(user1.id)
      expect(segment.matching_user_ids).to include(user2.id)
    end

    it "filters by user property" do
      user1 = create(:user_profile, project: project, properties: { "plan" => "pro" })
      user2 = create(:user_profile, project: project, properties: { "plan" => "free" })

      segment = create(:segment, project: project, conditions: [
        { "type" => "property", "key" => "plan", "operator" => "equals", "value" => "pro" }
      ])

      expect(segment.matching_user_ids).to include(user1.id)
      expect(segment.matching_user_ids).not_to include(user2.id)
    end

    it "applies multiple conditions with AND logic" do
      user1 = create(:user_profile, project: project, properties: { "plan" => "pro" })
      user2 = create(:user_profile, project: project, properties: { "plan" => "pro" })
      create(:event, project: project, user_profile: user1, name: "purchase", occurred_at: 1.day.ago)

      segment = create(:segment, project: project, conditions: [
        { "type" => "property", "key" => "plan", "operator" => "equals", "value" => "pro" },
        { "type" => "event", "event" => "purchase", "operator" => "did", "days" => 30 }
      ])

      ids = segment.matching_user_ids
      expect(ids).to include(user1.id)
      expect(ids).not_to include(user2.id)
    end
  end
end
