require "rails_helper"

RSpec.describe "Segments", type: :request do
  let(:project) { create(:project) }
  let!(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /projects/:project_id/segments" do
    it "lists segments" do
      create(:segment, project: project, name: "VIPs")
      get project_segments_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("VIPs")
    end
  end

  describe "GET /projects/:project_id/segments/new" do
    it "returns 200" do
      get new_project_segment_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /projects/:project_id/segments" do
    it "creates a segment with event conditions" do
      expect {
        post project_segments_path(project), params: {
          segment: {
            name: "Purchasers",
            conditions: [ { type: "event", event: "purchase", operator: "did", days: "30" } ]
          }
        }
      }.to change(Segment, :count).by(1)
      expect(response).to redirect_to(project_segment_path(project, Segment.last))
    end

    it "creates a segment with property conditions" do
      expect {
        post project_segments_path(project), params: {
          segment: {
            name: "Pro Users",
            conditions: [ { type: "property", key: "plan", operator: "equals", value: "pro" } ]
          }
        }
      }.to change(Segment, :count).by(1)
    end

    it "rejects invalid segment" do
      post project_segments_path(project), params: {
        segment: { name: "" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /projects/:project_id/segments/:id" do
    it "shows segment with user count" do
      segment = create(:segment, project: project)
      get project_segment_path(project, segment)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /projects/:project_id/segments/:id/edit" do
    it "returns 200" do
      segment = create(:segment, project: project)
      get edit_project_segment_path(project, segment)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /projects/:project_id/segments/:id" do
    it "updates segment" do
      segment = create(:segment, project: project)
      patch project_segment_path(project, segment), params: {
        segment: { name: "Updated Segment" }
      }
      expect(response).to redirect_to(project_segment_path(project, segment))
      expect(segment.reload.name).to eq("Updated Segment")
    end
  end

  describe "DELETE /projects/:project_id/segments/:id" do
    it "destroys segment" do
      segment = create(:segment, project: project)
      expect {
        delete project_segment_path(project, segment)
      }.to change(Segment, :count).by(-1)
      expect(response).to redirect_to(project_segments_path(project))
    end
  end
end
