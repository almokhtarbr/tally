class EventIngestionService
  class << self
    def track(project:, event_name:, user_id: nil, properties: {}, timestamp: nil, idempotency_key: nil)
      timestamp ||= Time.current
      user_profile = nil

      if user_id.present?
        user_profile = find_or_create_user_profile(project, user_id)
        user_profile.update_column(:last_seen_at, Time.current)
      end

      if idempotency_key.present?
        result = Event.upsert(
          {
            project_id: project.id,
            user_profile_id: user_profile&.id,
            name: event_name,
            properties: properties,
            idempotency_key: idempotency_key,
            occurred_at: timestamp,
            created_at: Time.current
          },
          unique_by: %i[project_id idempotency_key occurred_at]
        )
      else
        event = Event.create!(
          project: project,
          user_profile: user_profile,
          name: event_name,
          properties: properties || {},
          occurred_at: timestamp
        )
      end

      EventDailyRollup.increment!(project.id, event_name, timestamp.to_date)
      Project.where(id: project.id).update_counters(events_count: 1)

      if event.is_a?(Event)
        broadcast_event(event)
      end

      fire_webhooks(project, event_name, {
        event: event_name,
        user_id: user_id,
        properties: properties,
        timestamp: timestamp.iso8601,
        project_id: project.id
      })

      true
    end

    def identify(project:, user_id:, properties: {})
      user_profile = find_or_create_user_profile(project, user_id)
      user_profile.merge_properties!(properties)
      user_profile
    end

    def create_alias(project:, anonymous_id:, user_id:)
      user_profile = find_or_create_user_profile(project, user_id)

      alias_record = IdentityAlias.find_or_create_by!(
        project: project,
        anonymous_id: anonymous_id
      ) do |a|
        a.user_profile = user_profile
      end

      IdentityResolutionJob.perform_later(
        project_id: project.id,
        anonymous_id: anonymous_id,
        user_profile_id: user_profile.id
      )

      alias_record
    end

    private

    def broadcast_event(event)
      Turbo::StreamsChannel.broadcast_refresh_to("project_#{event.project_id}_events")
    rescue => e
      Rails.logger.warn("[Tally] Broadcast failed: #{e.message}")
    end

    def fire_webhooks(project, event_name, payload)
      project.webhooks.active.each do |webhook|
        next unless webhook.matches_event?(event_name)
        WebhookDeliveryJob.perform_later(
          webhook_id: webhook.id,
          event_name: event_name,
          payload: payload
        )
      end
    rescue => e
      Rails.logger.warn("[Tally] Webhook dispatch failed: #{e.message}")
    end

    def find_or_create_user_profile(project, external_id)
      now = Time.current
      UserProfile.find_or_create_by!(project: project, external_id: external_id) do |up|
        up.first_seen_at = now
        up.last_seen_at = now
      end
    end
  end
end
