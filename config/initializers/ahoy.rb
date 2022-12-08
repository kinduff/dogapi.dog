# frozen_string_literal: true

module Ahoy
  class Store < Ahoy::DatabaseStore
    def authenticate(data)
      # disables automatic linking of visits and users
    end
  end
end

Ahoy.mask_ips = true
Ahoy.cookies = false
Ahoy.api = false
Ahoy.track_bots = true
