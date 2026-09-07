require "rails_helper"

RSpec.describe SlackWebhookFormatter do
  describe ".slack_url?" do
    it "is true only for hooks.slack.com" do
      expect(described_class.slack_url?("https://hooks.slack.com/services/T/B/x")).to be true
      expect(described_class.slack_url?("https://example.com/hook")).to be false
      expect(described_class.slack_url?("not a url")).to be false
    end
  end

  describe ".call" do
    it "formats an anomaly payload" do
      body = described_class.call("anomaly", {
        event_name: "signup", anomaly_type: "drop", expected: 45.0, actual: 17.0, severity: "warning"
      })
      expect(body[:text]).to include("Anomaly").and include("signup").and include("45").and include("17")
    end

    it "formats a plain event payload" do
      body = described_class.call("purchase", { user_id: "u@x.com", properties: { "plan" => "pro" } })
      expect(body[:text]).to include("purchase").and include("u@x.com").and include("pro")
    end

    it "accepts string-keyed payloads (post-JSON round trip)" do
      body = described_class.call("anomaly", { "event_name" => "x", "anomaly_type" => "spike", "expected" => 1, "actual" => 9 })
      expect(body[:text]).to include("spike").and include("📈")
    end
  end
end
