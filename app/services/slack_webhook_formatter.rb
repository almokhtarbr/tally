# Turns a Tally webhook payload into a Slack incoming-webhook body when the
# destination is a Slack URL. Slack ignores our signature header, so the only
# change is the JSON shape.
module SlackWebhookFormatter
  module_function

  def slack_url?(url)
    URI.parse(url.to_s).host&.end_with?("hooks.slack.com")
  rescue URI::InvalidURIError
    false
  end

  def call(event_name, payload)
    p = payload.respond_to?(:with_indifferent_access) ? payload.with_indifferent_access : payload
    { text: text_for(event_name, p) }
  end

  def text_for(name, p)
    case name
    when "anomaly"
      arrow = p[:anomaly_type] == "spike" ? "📈" : "📉"
      "🚨 *Anomaly* #{arrow} — `#{p[:event_name]}` #{p[:anomaly_type]}: " \
        "expected ~#{p[:expected]}, saw #{p[:actual]} (#{p[:severity]})"
    else
      user = p[:user_id].present? ? " by #{p[:user_id]}" : ""
      props = p[:properties].presence && " · #{p[:properties].to_json}"
      "🔔 *#{name}*#{user}#{props}"
    end
  end
end
