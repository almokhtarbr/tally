module Api
  module V1
    class AliasController < BaseController
      def create
        anonymous_id = params.require(:anonymous_id)
        user_id = params.require(:user_id)

        EventIngestionService.create_alias(
          project: @project,
          anonymous_id: anonymous_id,
          user_id: user_id
        )

        render json: { status: "accepted" }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      end
    end
  end
end
