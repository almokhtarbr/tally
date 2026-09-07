require "net/http"

class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  def perform(webhook_id:, event_name:, payload:)
    webhook = Webhook.find_by(id: webhook_id)
    return unless webhook&.active?

    uri = URI.parse(webhook.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    # A Slack incoming webhook wants { "text": … }; everyone else gets the raw
    # Tally payload with an HMAC signature they can verify.
    body =
      if SlackWebhookFormatter.slack_url?(webhook.url)
        SlackWebhookFormatter.call(event_name, payload).to_json
      else
        payload.to_json
      end

    request = Net::HTTP::Post.new(uri.path.presence || "/")
    request["Content-Type"] = "application/json"
    request["X-Tally-Event"] = event_name
    request["X-Tally-Signature"] = webhook.sign_payload(body)
    request.body = body

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      webhook.record_success!
    else
      webhook.record_failure!
      Rails.logger.warn("[Tally Webhook] #{webhook.url} returned #{response.code}")
    end
  rescue => e
    webhook&.record_failure!
    Rails.logger.warn("[Tally Webhook] Delivery failed for #{webhook&.url}: #{e.message}")
  end
end
