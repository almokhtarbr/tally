module RequestSpecHelpers
  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end

  def api_headers(api_key)
    { "X-API-Key" => api_key, "Content-Type" => "application/json" }
  end

  def bearer_headers(api_secret)
    { "Authorization" => "Bearer #{api_secret}", "Content-Type" => "application/json" }
  end
end
