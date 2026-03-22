class Rack::Attack
  throttle("api/track", limit: 120, period: 60) do |req|
    req.env["HTTP_X_API_KEY"] if req.path.start_with?("/api/v1/track") && req.post?
  end

  throttle("api/batch", limit: 60, period: 60) do |req|
    req.env["HTTP_X_API_KEY"] if req.path.start_with?("/api/v1/batch") && req.post?
  end

  throttle("api/queries", limit: 60, period: 60) do |req|
    req.env["HTTP_AUTHORIZATION"] if req.path.start_with?("/api/v1/queries")
  end
end
