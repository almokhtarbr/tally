require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  let(:project) { create(:project, name: "Acme") }
  let(:user)    { create(:user, email: "owner@acme.test") }

  it "renders the weekly digest with headline numbers" do
    create(:event_daily_rollup, project:, event_name: "signup", date: 2.days.ago.to_date, count: 42)

    mail = described_class.weekly(project, user)

    expect(mail.to).to eq([ "owner@acme.test" ])
    expect(mail.subject).to include("Acme").and include("42")
    expect(mail.body.encoded).to include("42").and include("signup")
  end

  it "sends nothing when the project had no activity in either week" do
    mail = described_class.weekly(project, user)
    expect(mail.to).to be_nil     # #mail was never called
    expect { mail.deliver_now }.not_to change { ActionMailer::Base.deliveries.size }
  end
end
