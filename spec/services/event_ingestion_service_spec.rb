require "rails_helper"

RSpec.describe EventIngestionService do
  let(:project) { create(:project) }

  describe ".track" do
    it "creates an event" do
      expect {
        EventIngestionService.track(project: project, event_name: "signup")
      }.to change(Event, :count).by(1)
    end

    it "creates a user profile when user_id is provided" do
      expect {
        EventIngestionService.track(project: project, event_name: "signup", user_id: "user@test.com")
      }.to change(UserProfile, :count).by(1)
    end

    it "reuses existing user profile" do
      create(:user_profile, project: project, external_id: "user@test.com")
      expect {
        EventIngestionService.track(project: project, event_name: "signup", user_id: "user@test.com")
      }.not_to change(UserProfile, :count)
    end

    it "stores event properties" do
      EventIngestionService.track(
        project: project,
        event_name: "purchase",
        properties: { "amount" => 99, "plan" => "pro" }
      )
      event = Event.last
      expect(event.properties["amount"]).to eq(99)
      expect(event.properties["plan"]).to eq("pro")
    end

    it "increments daily rollup" do
      expect {
        EventIngestionService.track(project: project, event_name: "signup")
      }.to change(EventDailyRollup, :count).by(1)
    end

    it "increments project events_count" do
      EventIngestionService.track(project: project, event_name: "signup")
      expect(project.reload.events_count).to eq(1)
    end

    it "handles idempotency keys" do
      ts = Time.current
      2.times do
        EventIngestionService.track(
          project: project,
          event_name: "signup",
          idempotency_key: "unique_key_123",
          timestamp: ts
        )
      end
      # Rollup increments each time, but event is deduplicated (unique on project+key+occurred_at)
      expect(Event.where(idempotency_key: "unique_key_123").count).to eq(1)
    end

    it "fires matching webhooks" do
      webhook = create(:webhook, project: project, event_names: ["signup"])
      expect {
        EventIngestionService.track(project: project, event_name: "signup")
      }.to have_enqueued_job(WebhookDeliveryJob)
    end

    it "does not fire non-matching webhooks" do
      create(:webhook, project: project, event_names: ["purchase"])
      expect {
        EventIngestionService.track(project: project, event_name: "signup")
      }.not_to have_enqueued_job(WebhookDeliveryJob)
    end
  end

  describe ".identify" do
    it "creates a user profile" do
      profile = EventIngestionService.identify(
        project: project,
        user_id: "user@test.com",
        properties: { "name" => "Jane" }
      )
      expect(profile.external_id).to eq("user@test.com")
      expect(profile.properties["name"]).to eq("Jane")
    end

    it "merges properties on existing user" do
      create(:user_profile, project: project, external_id: "user@test.com", properties: { "name" => "Jane" })
      profile = EventIngestionService.identify(
        project: project,
        user_id: "user@test.com",
        properties: { "plan" => "pro" }
      )
      expect(profile.properties).to eq({ "name" => "Jane", "plan" => "pro" })
    end
  end

  describe ".create_alias" do
    it "creates an identity alias" do
      expect {
        EventIngestionService.create_alias(
          project: project,
          anonymous_id: "anon_123",
          user_id: "user@test.com"
        )
      }.to change(IdentityAlias, :count).by(1)
    end

    it "enqueues identity resolution job" do
      expect {
        EventIngestionService.create_alias(
          project: project,
          anonymous_id: "anon_123",
          user_id: "user@test.com"
        )
      }.to have_enqueued_job(IdentityResolutionJob)
    end
  end
end
