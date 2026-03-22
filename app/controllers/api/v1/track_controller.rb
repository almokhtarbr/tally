module Api
  module V1
    class TrackController < BaseController
      rate_limit to: 100, within: 1.minute, by: -> { request.headers["X-API-Key"] }

      def create
        event_name = params.require(:event)

        EventIngestionService.track(
          project: @project,
          event_name: event_name,
          user_id: params[:user_id],
          properties: params[:properties]&.to_unsafe_h || {},
          timestamp: params[:timestamp] ? Time.parse(params[:timestamp]) : nil,
          idempotency_key: params[:idempotency_key]
        )

        render json: { status: "accepted" }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      rescue => e
        render json: { error: "Internal server error" }, status: :internal_server_error
      end
    end
  end
end
