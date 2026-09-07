require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:project) { create(:project) }
  let!(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /projects/:id (show)" do
    it "returns 200 with date range and KPIs" do
      create(:event_daily_rollup, project: project, event_name: "$pageview", date: Date.current, count: 10)
      get project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("10")
    end

    it "accepts custom date range" do
      get project_path(project, from: 14.days.ago.to_date, to: Date.current)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /projects" do
    it "creates a new project" do
      expect {
        post projects_path, params: { project: { name: "New App", url: "https://new.app" } }
      }.to change(Project, :count).by(1)
      expect(response).to redirect_to(project_path(Project.last))
    end

    it "rejects invalid project" do
      post projects_path, params: { project: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /projects/:id" do
    it "updates project" do
      patch project_path(project), params: { project: { name: "Updated" } }
      expect(response).to redirect_to(project_path(project))
      expect(project.reload.name).to eq("Updated")
    end
  end

  describe "DELETE /projects/:id" do
    it "destroys project" do
      project # ensure created
      expect {
        delete project_path(project)
      }.to change(Project, :count).by(-1)
      expect(response).to redirect_to(projects_path)
    end
  end

  describe "GET /projects/:id/api_keys" do
    it "returns 200" do
      get api_keys_project_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:id/event_explorer" do
    it "returns 200" do
      get event_explorer_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "filters by event name" do
      create(:event, project: project, name: "signup", occurred_at: Time.current)
      get event_explorer_project_path(project, event_name: "signup")
      expect(response).to have_http_status(:ok)
    end

    it "supports group_by" do
      create(:event, project: project, name: "signup", properties: { "plan" => "pro" }, occurred_at: Time.current)
      get event_explorer_project_path(project, group_by: "plan")
      expect(response).to have_http_status(:ok)
    end

    it "supports pagination" do
      get event_explorer_project_path(project, page: 2)
      expect(response).to have_http_status(:ok)
    end

    it "renders a two-dimensional breakdown with group_by + second_group_by" do
      now = Time.current
      create(:event, project: project, name: "signup", properties: { "plan" => "pro", "country" => "US" }, occurred_at: now)
      create(:event, project: project, name: "signup", properties: { "plan" => "pro", "country" => "CA" }, occurred_at: now)
      create(:event, project: project, name: "signup", properties: { "plan" => "free", "country" => "US" }, occurred_at: now)

      get event_explorer_project_path(project, group_by: "plan", second_group_by: "country")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("plan").and include("country")
      # the primary × secondary table header
      expect(response.body).to include("Breakdown:")
      expect(response.body).to include("US").and include("CA")
    end

    it "keeps second_group_by in the date-range form so it survives a range change" do
      get event_explorer_project_path(project, group_by: "plan", second_group_by: "country")
      expect(response.body).to include('name="second_group_by" value="country"')
    end
  end

  describe "GET /projects/:id/funnels" do
    it "returns 200 without steps" do
      get funnels_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "computes funnel with steps" do
      user_profile = create(:user_profile, project: project)
      create(:event, project: project, user_profile: user_profile, name: "signup", occurred_at: 2.days.ago)
      create(:event, project: project, user_profile: user_profile, name: "purchase", occurred_at: 1.day.ago)
      get funnels_project_path(project, steps: [ "signup", "purchase" ], from: 7.days.ago.to_date, to: Date.current)
      expect(response).to have_http_status(:ok)
    end

    it "supports property filter" do
      get funnels_project_path(project, steps: [ "signup" ], filter_prop_key: "plan", filter_prop_value: "pro")
      expect(response).to have_http_status(:ok)
    end

    it "supports segment filter" do
      segment = create(:segment, project: project)
      get funnels_project_path(project, steps: [ "signup", "purchase" ], segment_id: segment.id)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:id/retention" do
    it "returns 200 with weekly granularity" do
      get retention_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "supports daily granularity" do
      get retention_project_path(project, granularity: "daily")
      expect(response).to have_http_status(:ok)
    end

    it "supports property filter" do
      get retention_project_path(project, filter_prop_key: "plan", filter_prop_value: "pro")
      expect(response).to have_http_status(:ok)
    end

    it "supports segment filter" do
      segment = create(:segment, project: project)
      get retention_project_path(project, segment_id: segment.id)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:id/errors" do
    it "returns 200" do
      get errors_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "filters by error type" do
      get errors_project_path(project, error_type: "frontend")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:id/users" do
    it "returns 200" do
      get users_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "searches users" do
      create(:user_profile, project: project, external_id: "alice@example.com")
      get users_project_path(project, q: "alice")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("alice@example.com")
    end

    it "filters by segment" do
      segment = create(:segment, project: project)
      get users_project_path(project, segment_id: segment.id)
      expect(response).to have_http_status(:ok)
    end

    it "supports pagination" do
      get users_project_path(project, page: 1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:id/user_paths" do
    it "returns 200" do
      get user_paths_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "accepts start_event and depth" do
      get user_paths_project_path(project, start_event: "signup", depth: 3)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:id/forms" do
    it "returns 200" do
      get forms_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "detects forms from form_submit events" do
      create(:event, project: project, name: "$form_submit",
        properties: { "selector" => "form#signup" }, occurred_at: Time.current)
      get forms_project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("form#signup")
    end

    it "shows form detail when form param is provided" do
      create(:event, project: project, name: "$form_submit",
        properties: { "selector" => "form#checkout" }, occurred_at: Time.current)
      create(:event, project: project, name: "$input_change",
        properties: { "form_selector" => "form#checkout", "field_name" => "email" }, occurred_at: Time.current)
      get forms_project_path(project, form: "form#checkout")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Field Drop-off")
    end
  end

  describe "GET /projects/:id/errors (business impact)" do
    it "includes business impact data" do
      user_profile = create(:user_profile, project: project)
      create(:event, project: project, user_profile: user_profile, name: "$error",
        properties: { "message" => "test" }, occurred_at: Time.current)
      get errors_project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Business Impact")
    end
  end

  describe "GET /projects/:id/anomalies" do
    it "returns 200" do
      get anomalies_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "shows active anomalies" do
      create(:anomaly, project: project, event_name: "signup", anomaly_type: "drop",
        severity: "critical", detected_at: Time.current)
      get anomalies_project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("signup")
      expect(response.body).to include("CRITICAL")
    end

    it "shows resolved anomalies in date range" do
      create(:anomaly, project: project, event_name: "purchase", anomaly_type: "spike",
        severity: "warning", detected_at: 1.day.ago, resolved_at: Time.current)
      get anomalies_project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("purchase")
    end
  end

  describe "GET /projects/:id/export_csv" do
    it "exports events CSV" do
      create(:event, project: project, name: "signup", occurred_at: Time.current)
      get export_csv_project_path(project, type: "events")
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("Event,User,Timestamp,Properties")
    end

    it "exports users CSV" do
      create(:user_profile, project: project, external_id: "test@example.com")
      get export_csv_project_path(project, type: "users")
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("External ID,First Seen,Last Seen,Properties")
    end

    it "exports funnel CSV" do
      get export_csv_project_path(project, type: "funnel", steps: [ "signup", "purchase" ])
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("Step,Users")
    end

    it "exports retention CSV" do
      get export_csv_project_path(project, type: "retention")
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("Cohort,Users")
    end
  end
end
