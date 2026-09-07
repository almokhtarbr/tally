require "rails_helper"

RSpec.describe AuditEvent, type: :model do
  it "requires an action and a summary" do
    expect(build(:audit_event, action: nil)).not_to be_valid
    expect(build(:audit_event, summary: nil)).not_to be_valid
  end

  it "falls back to 'System' when the actor is gone" do
    event = create(:audit_event, user: nil)
    expect(event.actor_name).to eq("System")
  end

  it "recent orders newest first" do
    old = create(:audit_event, created_at: 2.days.ago)
    fresh = create(:audit_event, created_at: 1.hour.ago)
    expect(AuditEvent.recent.to_a).to eq([ fresh, old ])
  end

  it "is removed with its project" do
    event = create(:audit_event)
    expect { event.project.destroy }.to change(AuditEvent, :count).by(-1)
  end
end
