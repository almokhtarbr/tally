class DigestMailer < ApplicationMailer
  # The weekly summary for one project, to one member. Sent by
  # SendWeeklyDigestsJob on Monday mornings; skipped when the project had no
  # events in the window so nobody gets an empty email.
  def weekly(project, user)
    @project = project
    @user    = user
    @digest  = ProjectDigest.new(project)
    return if @digest.events.current.zero? && @digest.events.previous.zero?

    mail to: user.email,
      subject: "#{project.name}: #{ActiveSupport::NumberHelper.number_to_delimited(@digest.events.current)} events this week"
  end
end
