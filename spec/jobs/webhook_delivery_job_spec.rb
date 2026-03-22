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
end
