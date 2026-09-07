# A read-only dashboard for a project, reached by its share token — no login.
# Headline numbers only; it deliberately doesn't expose the drill-downs.
class PublicDashboardsController < ApplicationController
  layout "public"

  SYSTEM_EVENTS = ProjectsController::SYSTEM_EVENTS

  def show
    @project = Project.find_by!(share_token: params[:token])
    @to   = Date.current
    @from = @to - 29

    rollups = @project.event_daily_rollups.where(date: @from..@to)
    @pageviews     = rollups.where(event_name: "$pageview").sum(:count)
    @custom_events = rollups.where.not(event_name: SYSTEM_EVENTS + [ "$pageview" ]).sum(:count)
    @sessions      = rollups.where(event_name: "$session_start").sum(:count)

    @visitors = @project.events
      .where(occurred_at: @from.beginning_of_day..@to.end_of_day)
      .where.not(name: SYSTEM_EVENTS)
      .distinct.count("COALESCE(properties->>'anonymous_id', user_profile_id::text)")

    @top_events = rollups.where.not(event_name: SYSTEM_EVENTS)
      .group(:event_name).order(Arel.sql("SUM(count) DESC")).limit(8).sum(:count).to_a

    @daily = rollups.where.not(event_name: SYSTEM_EVENTS)
      .group(:date).order(:date).sum(:count)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
