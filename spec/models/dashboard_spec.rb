require "rails_helper"

RSpec.describe Dashboard, type: :model do
  it "requires a name" do
    expect(build(:dashboard, name: nil)).not_to be_valid
  end

  describe "#pin" do
    let(:dashboard) { create(:dashboard) }
    let(:report) { create(:saved_report, project: dashboard.project) }

    it "appends the report as the next widget" do
      first = create(:saved_report, project: dashboard.project)
      dashboard.pin(first)
      dashboard.pin(report)

      expect(dashboard.dashboard_widgets.pluck(:saved_report_id, :position))
        .to eq([ [ first.id, 0 ], [ report.id, 1 ] ])
    end

    it "is idempotent for a report already pinned" do
      dashboard.pin(report)
      expect { dashboard.pin(report) }.not_to change { dashboard.dashboard_widgets.count }
    end

    it "orders saved_reports through widgets by position" do
      a = create(:saved_report, project: dashboard.project, name: "A")
      b = create(:saved_report, project: dashboard.project, name: "B")
      dashboard.pin(b)
      dashboard.pin(a)
      expect(dashboard.reload.saved_reports.to_a).to eq([ b, a ])
    end
  end

  it "removes its widgets when destroyed" do
    dashboard = create(:dashboard)
    dashboard.pin(create(:saved_report, project: dashboard.project))
    expect { dashboard.destroy }.to change(DashboardWidget, :count).by(-1)
  end
end
