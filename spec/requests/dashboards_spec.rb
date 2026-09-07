require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  let(:project) { create(:project) }
  let!(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /projects/:project_id/dashboards" do
    it "lists the project's dashboards" do
      create(:dashboard, project: project, name: "Marketing")
      get project_dashboards_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Marketing")
    end
  end

  describe "POST /projects/:project_id/dashboards" do
    it "creates a dashboard and redirects to it" do
      expect {
        post project_dashboards_path(project), params: { dashboard: { name: "Exec" } }
      }.to change(project.dashboards, :count).by(1)
      expect(response).to redirect_to(project_dashboard_path(project, project.dashboards.last))
    end

    it "rejects a blank name" do
      post project_dashboards_path(project), params: { dashboard: { name: "" } }
      expect(response).to redirect_to(project_dashboards_path(project))
      expect(project.dashboards.count).to eq(0)
    end
  end

  describe "GET /projects/:project_id/dashboards/:id" do
    it "renders pinned widgets with their headline metric" do
      dashboard = create(:dashboard, project: project)
      report = create(:saved_report, project: project, name: "Signups",
        report_type: "event_explorer", configuration: { "event_name" => "signup" })
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 12)
      dashboard.pin(report)

      get project_dashboard_path(project, dashboard)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Signups")
      expect(response.body).to include("12")
    end
  end

  describe "widgets" do
    let(:dashboard) { create(:dashboard, project: project) }
    let(:report) { create(:saved_report, project: project) }

    it "pins a saved report" do
      expect {
        post project_dashboard_dashboard_widgets_path(project, dashboard),
          params: { saved_report_id: report.id }
      }.to change(dashboard.dashboard_widgets, :count).by(1)
    end

    it "pins with a chosen day range and can change it later" do
      post project_dashboard_dashboard_widgets_path(project, dashboard),
        params: { saved_report_id: report.id, range_days: 90 }
      widget = dashboard.dashboard_widgets.last
      expect(widget.range_days).to eq(90)

      patch project_dashboard_dashboard_widget_path(project, dashboard, widget),
        params: { range_days: 7 }
      expect(widget.reload.range_days).to eq(7)
    end

    it "falls back to the default for a junk range" do
      post project_dashboard_dashboard_widgets_path(project, dashboard),
        params: { saved_report_id: report.id, range_days: 999 }
      expect(dashboard.dashboard_widgets.last.range_days).to eq(30)
    end

    it "removes a widget" do
      widget = dashboard.pin(report)
      expect {
        delete project_dashboard_dashboard_widget_path(project, dashboard, widget)
      }.to change(dashboard.dashboard_widgets, :count).by(-1)
    end

    it "won't pin a report from another project" do
      other = create(:saved_report, project: create(:project))
      expect {
        post project_dashboard_dashboard_widgets_path(project, dashboard),
          params: { saved_report_id: other.id }
      }.not_to change(dashboard.dashboard_widgets, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /projects/:project_id/dashboards/:id" do
    it "deletes the dashboard" do
      dashboard = create(:dashboard, project: project)
      expect {
        delete project_dashboard_path(project, dashboard)
      }.to change(project.dashboards, :count).by(-1)
    end
  end

  context "without a signed-in user" do
    before { reset! }

    it "redirects to login" do
      get project_dashboards_path(project)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
