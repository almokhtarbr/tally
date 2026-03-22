require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with valid attributes" do
    user = build(:user)
    expect(user).to be_valid
  end

  it "requires email" do
    user = build(:user, email: nil)
    expect(user).not_to be_valid
  end

  it "requires unique email" do
    create(:user, email: "dup@example.com")
    user = build(:user, email: "dup@example.com")
    expect(user).not_to be_valid
  end

  it "validates email format" do
    user = build(:user, email: "not-an-email")
    expect(user).not_to be_valid
  end

  it "requires name" do
    user = build(:user, name: nil)
    expect(user).not_to be_valid
  end

  it "requires role" do
    user = build(:user, role: nil)
    expect(user).not_to be_valid
  end

  it "validates role inclusion" do
    user = build(:user, role: "superuser")
    expect(user).not_to be_valid
  end

  it "authenticates with correct password" do
    user = create(:user, password: "secret123", password_confirmation: "secret123")
    expect(user.authenticate("secret123")).to eq(user)
    expect(user.authenticate("wrong")).to be false
  end

  it "admin? returns true for admins" do
    admin = build(:user, role: "admin")
    member = build(:user, role: "member")
    expect(admin.admin?).to be true
    expect(member.admin?).to be false
  end

  it "can_access_project? returns true for admins" do
    admin = create(:user, role: "admin")
    project = create(:project)
    expect(admin.can_access_project?(project)).to be true
  end

  it "can_access_project? checks membership for non-admins" do
    member = create(:user, role: "member")
    project = create(:project)
    expect(member.can_access_project?(project)).to be false

    create(:project_membership, user: member, project: project)
    expect(member.can_access_project?(project)).to be true
  end
end
