# frozen_string_literal: true

# Throttling counters live in Redis when it is available, so the limit is shared
# by every process and survives restarts. Without REDIS_URL (development, test)
# the in-process store is used instead.
Rack::Attack.cache.store =
  if ENV["REDIS_URL"].present?
    ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV["REDIS_URL"],
      namespace: "rack-attack",
      connect_timeout: 1,
      read_timeout: 0.5,
      write_timeout: 0.5,
      reconnect_attempts: 1,
      # A Redis outage must not take the API down: requests are let through and
      # the error is logged instead.
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.error("Rack::Attack cache error in #{method}: #{exception.class}: #{exception.message}")
      }
    )
  else
    ActiveSupport::Cache::MemoryStore.new
  end

# Named rather than inline, so the number the docs quote is the number in force.
Rack::Attack::REQUESTS_PER_MINUTE = 300

# Behind Cloudflare the connection comes from one of a few hundred edge IPs,
# so throttling on `req.ip` would fold every user onto them and lock the whole
# API within seconds. Cloudflare sets CF-Connecting-IP to the real client on
# every proxied request and overwrites any value the client sent; without
# Cloudflare in front the header is absent and the connection IP is used.
Rack::Attack.throttle("req/ip", limit: Rack::Attack::REQUESTS_PER_MINUTE, period: 1.minute) do |req|
  req.env["HTTP_CF_CONNECTING_IP"].presence || req.ip
end

Rack::Attack.enabled = Rails.env.production?
