require "rails_helper"

RSpec.describe "Saved Reports", type: :request do
  let(:project) { create(:project) }
  let!(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /projects/:project_id/saved_reports" do
    it "lists saved reports" do
      create(:saved_report, project: project, name: "Weekly Funnel")
      get project_saved_reports_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weekly Funnel")
    end
  end

  describe "POST /projects/:project_id/saved_reports" do
    it "creates a saved report" do
      expect {
        post project_saved_reports_path(project), params: {
          saved_report: {
            name: "My Funnel",
            report_type: "funnel",
            configuration: { steps: ["signup", "purchase"], window: "7d" }
          }
        }
      }.to change(SavedReport, :count).by(1)
    end

    it "rejects invalid report" do
      post project_saved_reports_path(project), params: {
        saved_report: { name: "", report_type: "funnel", configuration: { steps: [] } }
      }
      # Redirects back with alert
      expect(response).to be_redirect
    end
  end

  describe "GET /projects/:project_id/saved_reports/:id (show redirects)" do
    it "redirects funnel report to funnels page" do
      report = create(:saved_report, project: project, report_type: "funnel", configuration: { "steps" => ["signup"], "window" => "7d" })
      get project_saved_report_path(project, report)
      expect(response).to redirect_to(funnels_project_path(project, steps: ["signup"], window: "7d"))
    end

    it "redirects retention report to retention page" do
      report = create(:saved_report, project: project, report_type: "retention", configuration: { "granularity" => "weekly" })
      get project_saved_report_path(project, report)
      expect(response).to redirect_to(retention_project_path(project, granularity: "weekly"))
    end
  end

  describe "DELETE /projects/:project_id/saved_reports/:id" do
    it "destroys the report" do
      report = create(:saved_report, project: project)
      expect {
        delete project_saved_report_path(project, report)
      }.to change(SavedReport, :count).by(-1)
      expect(response).to redirect_to(project_saved_reports_path(project))
    end
  end
end
