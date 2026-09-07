require "rails_helper"

RSpec.describe WidgetMetric do
  let(:project) { create(:project) }

  def rollup(event_name, count, days_ago: 1)
    create(:event_daily_rollup, project: project, event_name: event_name,
      date: days_ago.days.ago.to_date, count: count)
  end

  it "returns nil for report types that don't reduce to one number" do
    report = create(:saved_report, project: project, report_type: "funnel")
    expect(described_class.new(report).call).to be_nil
  end

  it "sums a single event's rollups over the last 30 days" do
    rollup("signup", 4)
    rollup("signup", 6, days_ago: 10)
    rollup("signup", 99, days_ago: 40) # outside the window
    rollup("login", 50)                # different event

    report = create(:saved_report, project: project, report_type: "event_explorer",
      configuration: { "event_name" => "signup" })

    result = described_class.new(report).call
    expect(result.value).to eq(10)
    expect(result.label).to eq("signup · last 30d")
  end

  it "sums all non-system events when no event_name is configured" do
    rollup("signup", 3)
    rollup("login", 7)
    rollup("$session_start", 1000) # system event, excluded

    report = create(:saved_report, project: project, report_type: "trend",
      configuration: { "metric" => "total" })

    expect(described_class.new(report).call.value).to eq(10)
  end
end
