module Api
  module V1
    class BatchController < BaseController
      rate_limit to: 50, within: 1.minute, by: -> { request.headers["X-API-Key"] }

      def create
        events = params.require(:events)

        if events.length > 100
          return render json: { error: "Maximum 100 events per batch" }, status: :unprocessable_entity
        end

        events.each do |event_params|
          EventIngestionService.track(
            project: @project,
            event_name: event_params[:event] || event_params[:name],
            user_id: event_params[:user_id],
            properties: event_params[:properties]&.to_unsafe_h || {},
            timestamp: event_params[:timestamp] ? Time.parse(event_params[:timestamp]) : nil,
            idempotency_key: event_params[:idempotency_key]
          )
        end

        render json: { status: "accepted", received: events.length }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      end
    end
  end
end
