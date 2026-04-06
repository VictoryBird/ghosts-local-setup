# rack_attack.rb — Disable rate limiting for GHOSTS NPC cyber exercise
#
# This configuration effectively removes all Mastodon rate limits to allow
# bulk NPC automation (130 NPCs posting, following, boosting concurrently).
# DO NOT use this in any internet-facing deployment.

class Rack::Attack
  # Remove all default throttles
  throttles.clear
  blocklists.clear
  safelists.clear

  # Safelist everything
  safelist("allow-all") do |_req|
    true
  end
end

# Override specific Mastodon rate limits that may be defined elsewhere
Rack::Attack.throttle("throttle_authenticated_api", limit: 100_000, period: 300) do |req|
  req.authenticated_user_id if req.path.start_with?("/api/")
end

Rack::Attack.throttle("throttle_unauthenticated_api", limit: 100_000, period: 300) do |req|
  req.ip if req.path.start_with?("/api/")
end

Rack::Attack.throttle("throttle_authenticated_paging", limit: 100_000, period: 300) do |req|
  req.authenticated_user_id if req.params["max_id"].present? || req.params["min_id"].present?
end

Rack::Attack.throttle("throttle_login_attempts/ip", limit: 100_000, period: 300) do |req|
  req.ip if req.path == "/auth/sign_in" && req.post?
end

Rack::Attack.throttle("throttle_sign_up_attempts/ip", limit: 100_000, period: 300) do |req|
  req.ip if req.path == "/auth" && req.post?
end
