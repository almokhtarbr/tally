require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  let(:project) { create(:project) }
  let!(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /projects/:project_id/webhooks" do
    it "lists webhooks" do
      create(:webhook, project: project, url: "https://hooks.example.com/test")
      get project_webhooks_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hooks.example.com")
    end
  end

  describe "GET /projects/:project_id/webhooks/new" do
    it "returns 200" do
      get new_project_webhook_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /projects/:project_id/webhooks" do
    it "creates a webhook" do
      expect {
        post project_webhooks_path(project), params: {
          webhook: { url: "https://hooks.example.com/new", event_names: ["*"] }
        }
      }.to change(Webhook, :count).by(1)
      expect(response).to redirect_to(project_webhooks_path(project))
    end

    it "rejects invalid webhook" do
      post project_webhooks_path(project), params: {
        webhook: { url: "not-a-url" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /projects/:project_id/webhooks/:id/edit" do
    it "returns 200" do
      webhook = create(:webhook, project: project)
      get edit_project_webhook_path(project, webhook)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /projects/:project_id/webhooks/:id" do
    it "updates webhook" do
      webhook = create(:webhook, project: project)
      patch project_webhook_path(project, webhook), params: {
        webhook: { url: "https://hooks.example.com/updated", event_names: ["signup"] }
      }
      expect(response).to redirect_to(project_webhooks_path(project))
      expect(webhook.reload.url).to eq("https://hooks.example.com/updated")
    end
  end

  describe "DELETE /projects/:project_id/webhooks/:id" do
    it "destroys webhook" do
      webhook = create(:webhook, project: project)
      expect {
        delete project_webhook_path(project, webhook)
      }.to change(Webhook, :count).by(-1)
      expect(response).to redirect_to(project_webhooks_path(project))
    end
  end

  describe "POST /projects/:project_id/webhooks/:id/toggle" do
    it "toggles webhook active state" do
      webhook = create(:webhook, project: project, active: true)
      post toggle_project_webhook_path(project, webhook)
      expect(webhook.reload.active).to be false
    end
  end

  describe "POST /projects/:project_id/webhooks/:id/test" do
    it "enqueues a test webhook job" do
      webhook = create(:webhook, project: project)
      expect {
        post test_project_webhook_path(project, webhook)
      }.to have_enqueued_job(WebhookDeliveryJob)
      expect(response).to redirect_to(project_webhooks_path(project))
    end
  end
end
