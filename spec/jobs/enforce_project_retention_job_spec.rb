require "rails_helper"

RSpec.describe EnforceProjectRetentionJob, type: :job do
  let(:today) { Date.new(2026, 9, 15) }

  def event_at(project, days_ago)
    create(:event, project:, occurred_at: (today - days_ago).to_time)
  end

  it "prunes events older than the project's retention window, keeps newer" do
    project = create(:project, retention_days: 30)
    old   = event_at(project, 40)
    fresh = event_at(project, 10)
    create(:event_daily_rollup, project:, event_name: "x", date: today - 40, count: 3)
    create(:event_daily_rollup, project:, event_name: "x", date: today - 5,  count: 3)

    described_class.perform_now(today:)

    expect(Event.exists?(old.id)).to be false
    expect(Event.exists?(fresh.id)).to be true
    expect(project.event_daily_rollups.count).to eq(1)
  end

  it "ignores projects with no retention set" do
    project = create(:project, retention_days: nil)
    old = event_at(project, 400)
    described_class.perform_now(today:)
    expect(Event.exists?(old.id)).to be true
  end

  it "only touches the project that's over its window" do
    keep_project  = create(:project, retention_days: nil)
    prune_project = create(:project, retention_days: 7)
    kept   = event_at(keep_project, 100)
    pruned = event_at(prune_project, 100)

    described_class.perform_now(today:)

    expect(Event.exists?(kept.id)).to be true
    expect(Event.exists?(pruned.id)).to be false
  end
end
