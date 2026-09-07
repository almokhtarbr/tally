require "rails_helper"

RSpec.describe SendWeeklyDigestsJob do
  include ActiveJob::TestHelper

  it "enqueues one digest per opted-in membership, skips opted-out" do
    p1 = create(:project)
    p2 = create(:project)
    create(:event_daily_rollup, project: p1, event_name: "x", date: 1.day.ago.to_date, count: 5)
    create(:event_daily_rollup, project: p2, event_name: "x", date: 1.day.ago.to_date, count: 5)

    u1 = create(:user)
    u2 = create(:user)
    create(:project_membership, user: u1, project: p1, weekly_digest: true)
    create(:project_membership, user: u2, project: p1, weekly_digest: false)
    create(:project_membership, user: u1, project: p2, weekly_digest: true)

    expect {
      perform_enqueued_jobs { described_class.perform_now }
    }.to change { ActionMailer::Base.deliveries.size }.by(2)

    expect(ActionMailer::Base.deliveries.map(&:to).flatten).to all(eq(u1.email))
  end
end
