module Api
  module V1
    class QueriesController < BaseController
      skip_before_action :authenticate_project!
      before_action :authenticate_project_secret!

      def event_counts
        event_name = params.require(:event)
        from_date = Date.parse(params.require(:from))
        to_date = Date.parse(params.require(:to))
        granularity = params[:granularity] || "day"

        rollups = @project.event_daily_rollups
          .where(event_name: event_name, date: from_date..to_date)
          .order(:date)

        data = if granularity == "month"
          rollups.group_by { |r| r.date.beginning_of_month }
            .map { |month, records| { date: month.to_s, count: records.sum(&:count) } }
        else
          rollups.map { |r| { date: r.date.to_s, count: r.count } }
        end

        render json: { event: event_name, granularity: granularity, data: data }
      end

      def top_events
        from_date = Date.parse(params.require(:from))
        to_date = Date.parse(params.require(:to))
        limit = (params[:limit] || 10).to_i

        data = @project.event_daily_rollups
          .where(date: from_date..to_date)
          .group(:event_name)
          .sum(:count)
          .sort_by { |_, count| -count }
          .first(limit)
          .map { |name, count| { event: name, count: count } }

        render json: { data: data }
      end

      def user_timeline
        user_id = params.require(:user_id)
        limit = (params[:limit] || 50).to_i

        user_profile = @project.user_profiles.find_by!(external_id: user_id)

        events = user_profile.events.chronological

        if params[:from].present?
          events = events.where("occurred_at >= ?", Time.parse(params[:from]))
        end
        if params[:to].present?
          events = events.where("occurred_at <= ?", Time.parse(params[:to]))
        end

        data = events.limit(limit).map do |e|
          { event: e.name, properties: e.properties, timestamp: e.occurred_at.iso8601 }
        end

        render json: { user_id: user_id, data: data }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      end
    end
  end
end
