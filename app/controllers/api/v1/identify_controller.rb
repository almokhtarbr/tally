module Api
  module V1
    class IdentifyController < BaseController
      def create
        user_id = params.require(:user_id)
        properties = params.require(:properties).to_unsafe_h

        EventIngestionService.identify(
          project: @project,
          user_id: user_id,
          properties: properties
        )

        render json: { status: "accepted" }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      end
    end
  end
end
