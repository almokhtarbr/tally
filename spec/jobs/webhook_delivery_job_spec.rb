require "rails_helper"

RSpec.describe WebhookDeliveryJob, type: :job do
  let(:project) { create(:project) }
  let(:webhook) { create(:webhook, project: project) }

  it "is enqueued in the default queue" do
    expect(WebhookDeliveryJob.new.queue_name).to eq("default")
  end

  it "handles missing webhook gracefully" do
    expect {
      WebhookDeliveryJob.perform_now(
        webhook_id: 0,
        event_name: "test",
        payload: { event: "test" }
      )
    }.not_to raise_error
  end

  it "skips inactive webhooks" do
    webhook.update!(active: false)
    # Should not make any HTTP request
    expect {
      WebhookDeliveryJob.perform_now(
        webhook_id: webhook.id,
        event_name: "test",
        payload: { event: "test" }
      )
    }.not_to raise_error
  end

  describe "request body" do
    def captured_body_for(url)
      sent = nil
      fake_response = instance_double(Net::HTTPResponse, code: "200")
      allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
        sent = req.body
        fake_response
      end
      WebhookDeliveryJob.perform_now(
        webhook_id: create(:webhook, project:, url:).id,
        event_name: "anomaly",
        payload: { event_name: "signup", anomaly_type: "drop", expected: 45.0, actual: 17.0, severity: "warning" }
      )
      sent
    end

    it "sends the raw Tally payload to a generic URL" do
      body = JSON.parse(captured_body_for("https://example.com/hook"))
      expect(body).to include("anomaly_type" => "drop", "severity" => "warning")
    end

    it "sends a Slack { text: … } body to a hooks.slack.com URL" do
      body = JSON.parse(captured_body_for("https://hooks.slack.com/services/T/B/xxx"))
      expect(body.keys).to eq([ "text" ])
      expect(body["text"]).to include("Anomaly").and include("signup")
    end
  end
end
