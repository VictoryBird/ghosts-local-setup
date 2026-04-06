# rack_attack.rb — Disable rate limiting for GHOSTS NPC cyber exercise
# DO NOT use this in any internet-facing deployment.

class Rack::Attack
  # Safelist everything — no throttling for training environment
  safelist("allow-all") do |_req|
    true
  end
end
