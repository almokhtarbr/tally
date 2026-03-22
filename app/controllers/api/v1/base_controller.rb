module Api
  module V1
    class BaseController < ActionController::API
      before_action :parse_body_if_needed
      before_action :authenticate_project!

      private

      def parse_body_if_needed
        return if request.content_type&.include?("application/json")
        return if request.body.nil?

        body = request.body.read
        return if body.blank?

        begin
          parsed = JSON.parse(body)
          parsed.each { |k, v| params[k] = v }
        rescue JSON::ParserError
        end
      end

      def authenticate_project!
        api_key = request.headers["X-API-Key"] || params[:api_key]
        @project = Project.find_by(api_key: api_key)
        render json: { error: "Invalid API key" }, status: :unauthorized unless @project
      end

      def authenticate_project_secret!
        token = request.headers["Authorization"]&.remove("Bearer ")
        @project = Project.find_by(api_secret: token)
        render json: { error: "Invalid API secret" }, status: :unauthorized unless @project
      end
    end
  end
end
