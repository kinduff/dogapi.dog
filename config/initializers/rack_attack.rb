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

Rack::Attack.throttle("req/ip", limit: Rack::Attack::REQUESTS_PER_MINUTE, period: 1.minute, &:ip)

Rack::Attack.enabled = Rails.env.production?
