require "rails_helper"

RSpec.describe UserProfile, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it "requires an external_id" do
      up = UserProfile.new(project: project, external_id: nil)
      expect(up).not_to be_valid
    end

    it "enforces uniqueness of external_id within project" do
      create(:user_profile, project: project, external_id: "user1")
      dup = build(:user_profile, project: project, external_id: "user1")
      expect(dup).not_to be_valid
    end

    it "allows same external_id across different projects" do
      other = create(:project, name: "Other")
      create(:user_profile, project: project, external_id: "user1")
      up = build(:user_profile, project: other, external_id: "user1")
      expect(up).to be_valid
    end
  end

  describe "#merge_properties!" do
    it "merges new properties with existing ones" do
      up = create(:user_profile, project: project, properties: { "name" => "Jane" })
      up.merge_properties!({ "plan" => "pro" })
      expect(up.reload.properties).to eq({ "name" => "Jane", "plan" => "pro" })
    end

    it "overwrites existing keys" do
      up = create(:user_profile, project: project, properties: { "plan" => "free" })
      up.merge_properties!({ "plan" => "pro" })
      expect(up.reload.properties["plan"]).to eq("pro")
    end

    it "removes keys set to nil" do
      up = create(:user_profile, project: project, properties: { "name" => "Jane", "plan" => "pro" })
      up.merge_properties!({ "plan" => nil })
      expect(up.reload.properties).to eq({ "name" => "Jane" })
    end
  end
end
