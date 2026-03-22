require "rails_helper"

RSpec.describe ProjectMembership, type: :model do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  it "is valid with valid attributes" do
    membership = build(:project_membership, user: user, project: project)
    expect(membership).to be_valid
  end

  it "requires role" do
    membership = build(:project_membership, user: user, project: project, role: nil)
    expect(membership).not_to be_valid
  end

  it "validates role inclusion" do
    membership = build(:project_membership, user: user, project: project, role: "superuser")
    expect(membership).not_to be_valid
  end

  it "accepts valid roles" do
    %w[owner editor viewer].each do |role|
      membership = build(:project_membership, user: user, project: project, role: role)
      expect(membership).to be_valid
    end
  end

  it "requires unique user per project" do
    create(:project_membership, user: user, project: project)
    duplicate = build(:project_membership, user: user, project: project)
    expect(duplicate).not_to be_valid
  end
end
