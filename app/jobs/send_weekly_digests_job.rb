# Monday-morning weekly digests. One email per (project, opted-in member).
# DigestMailer#weekly no-ops for a project with no activity, so quiet projects
# never send.
class SendWeeklyDigestsJob < ApplicationJob
  queue_as :default

  def perform
    ProjectMembership.where(weekly_digest: true).includes(:user, :project).find_each do |membership|
      DigestMailer.weekly(membership.project, membership.user).deliver_later
    end
  end
end
