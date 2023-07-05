# frozen_string_literal: true

module Rack
  class Attack
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    throttle("req/ip", limit: 300, period: 1.minute, &:ip)
  end
end

Rack::Attack.enabled = Rails.env.production?
