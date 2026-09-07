require "rails_helper"

RSpec.describe Webhook, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it "requires a url" do
      webhook = Webhook.new(project: project, url: nil, event_names: [ "*" ])
      expect(webhook).not_to be_valid
    end

    it "requires a valid HTTP URL" do
      webhook = Webhook.new(project: project, url: "not-a-url", event_names: [ "*" ])
      expect(webhook).not_to be_valid
    end

    it "accepts valid HTTPS URL" do
      webhook = Webhook.new(project: project, url: "https://example.com/webhook", event_names: [ "*" ])
      expect(webhook).to be_valid
    end
  end

  describe "#matches_event?" do
    it "matches wildcard" do
      webhook = create(:webhook, project: project, event_names: [ "*" ])
      expect(webhook.matches_event?("purchase")).to be true
    end

    it "matches specific event" do
      webhook = create(:webhook, project: project, event_names: [ "purchase", "signup" ])
      expect(webhook.matches_event?("purchase")).to be true
      expect(webhook.matches_event?("login")).to be false
    end
  end

  describe "#sign_payload" do
    it "generates HMAC-SHA256 signature" do
      webhook = create(:webhook, project: project)
      sig = webhook.sign_payload('{"test": true}')
      expect(sig).to be_a(String)
      expect(sig.length).to eq(64)
    end
  end

  describe "secret generation" do
    it "auto-generates whsec_ prefixed secret" do
      webhook = create(:webhook, project: project)
      expect(webhook.secret).to start_with("whsec_")
    end
  end

  describe "#record_failure!" do
    it "increments failure count" do
      webhook = create(:webhook, project: project)
      webhook.record_failure!
      expect(webhook.reload.failures).to eq(1)
    end

    it "disables after 10 failures" do
      webhook = create(:webhook, project: project, failures: 9)
      webhook.record_failure!
      expect(webhook.reload.active).to be false
    end
  end
end
