require "rails_helper"

RSpec.describe "Project audit log", type: :request do
  let(:project) { create(:project) }
  let!(:user) { create(:user, name: "Dana") }

  before { sign_in(user) }

  describe "GET /projects/:id/audit" do
    it "lists entries newest first" do
      create(:audit_event, project: project, summary: "Older thing", created_at: 2.days.ago)
      create(:audit_event, project: project, summary: "Newer thing", created_at: 1.hour.ago)

      get audit_project_path(project)

      expect(response).to have_http_status(:ok)
      expect(response.body.index("Newer thing")).to be < response.body.index("Older thing")
    end
  end

  it "records a project settings change with the actor and changed fields" do
    expect {
      patch project_path(project), params: { project: { name: "Renamed", retention_days: 45 } }
    }.to change(project.audit_events, :count).by(1)

    entry = project.audit_events.last
    expect(entry.action).to eq("project.update")
    expect(entry.user).to eq(user)
    expect(entry.metadata["fields"]).to contain_exactly("name", "retention_days")
  end

  it "does not log a no-op update" do
    patch project_path(project), params: { project: { name: project.name } }
    expect(project.audit_events.count).to eq(0)
  end

  it "records enabling and disabling the public link" do
    post share_project_path(project)
    delete unshare_project_path(project)

    expect(project.audit_events.recent.pluck(:action)).to eq([ "project.share_off", "project.share_on" ])
  end

  it "records webhook creation and deletion" do
    post project_webhooks_path(project), params: { webhook: { url: "https://example.com/hook", event_names: [ "*" ] } }
    webhook = project.webhooks.last
    delete project_webhook_path(project, webhook)

    expect(project.audit_events.recent.pluck(:action)).to eq([ "webhook.delete", "webhook.create" ])
  end
end
