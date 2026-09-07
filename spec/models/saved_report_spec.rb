require "rails_helper"

RSpec.describe SavedReport, type: :model do
  let(:project) { create(:project) }

  it "is valid with valid attributes" do
    report = build(:saved_report, project: project)
    expect(report).to be_valid
  end

  it "requires name" do
    report = build(:saved_report, project: project, name: nil)
    expect(report).not_to be_valid
  end

  it "requires report_type" do
    report = build(:saved_report, project: project, report_type: nil)
    expect(report).not_to be_valid
  end

  it "validates report_type inclusion" do
    report = build(:saved_report, project: project, report_type: "invalid")
    expect(report).not_to be_valid
  end

  it "accepts valid report types" do
    %w[funnel retention event_explorer trend].each do |type|
      report = build(:saved_report, project: project, report_type: type)
      expect(report).to be_valid
    end
  end

  it "requires configuration" do
    report = build(:saved_report, project: project, configuration: nil)
    expect(report).not_to be_valid
  end

  it "returns query params from configuration" do
    report = create(:saved_report, project: project, configuration: { "steps" => [ "a", "b" ] })
    params = report.to_query_params
    expect(params["steps"]).to eq([ "a", "b" ])
    expect(params["report_id"]).to eq(report.id)
  end

  it "scopes by_type" do
    create(:saved_report, project: project, report_type: "funnel")
    create(:saved_report, project: project, name: "Ret Report", report_type: "retention")
    expect(SavedReport.by_type("funnel").count).to eq(1)
  end

  it "scopes recent" do
    r1 = create(:saved_report, project: project, name: "Old", updated_at: 2.days.ago)
    r2 = create(:saved_report, project: project, name: "New", updated_at: 1.hour.ago)
    expect(SavedReport.recent.first).to eq(r2)
  end
end
