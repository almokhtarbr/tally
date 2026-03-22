require "rails_helper"

RSpec.describe Project, type: :model do
  describe "validations" do
    it "requires a name" do
      project = Project.new(name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to include("can't be blank")
    end

    it "requires unique api_key" do
      create(:project)
      project = build(:project, api_key: Project.first.api_key)
      expect(project).not_to be_valid
    end
  end

  describe "api key generation" do
    it "generates pk_ and sk_ prefixed keys on create" do
      project = create(:project)
      expect(project.api_key).to start_with("pk_")
      expect(project.api_secret).to start_with("sk_")
    end

    it "does not overwrite existing keys" do
      project = Project.new(name: "Test", api_key: "pk_custom", api_secret: "sk_custom")
      project.save!
      expect(project.api_key).to eq("pk_custom")
      expect(project.api_secret).to eq("sk_custom")
    end
  end

  describe "associations" do
    let(:project) { create(:project) }

    it "has many user_profiles" do
      expect(project).to respond_to(:user_profiles)
    end

    it "has many events" do
      expect(project).to respond_to(:events)
    end

    it "has many segments" do
      expect(project).to respond_to(:segments)
    end

    it "has many webhooks" do
      expect(project).to respond_to(:webhooks)
    end

    it "has many saved_reports" do
      expect(project).to respond_to(:saved_reports)
    end

    it "destroys dependents on delete" do
      up = create(:user_profile, project: project)
      create(:segment, project: project)
      project.destroy
      expect(UserProfile.find_by(id: up.id)).to be_nil
    end
  end
end
