class IdentityResolutionJob < ApplicationJob
  queue_as :default

  def perform(project_id:, anonymous_id:, user_profile_id:)
    project = Project.find(project_id)
    identified_profile = UserProfile.find(user_profile_id)

    anonymous_profile = project.user_profiles.find_by(external_id: anonymous_id)
    return unless anonymous_profile
    return if anonymous_profile.id == identified_profile.id

    Event.where(project_id: project_id, user_profile_id: anonymous_profile.id)
      .update_all(user_profile_id: identified_profile.id)

    if anonymous_profile.properties.present?
      merged = anonymous_profile.properties.merge(identified_profile.properties)
      identified_profile.update!(properties: merged)
    end

    if anonymous_profile.first_seen_at &&
       (identified_profile.first_seen_at.nil? || anonymous_profile.first_seen_at < identified_profile.first_seen_at)
      identified_profile.update!(first_seen_at: anonymous_profile.first_seen_at)
    end

    anonymous_profile.destroy!
  rescue ActiveRecord::RecordNotFound
  end
end
