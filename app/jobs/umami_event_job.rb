# frozen_string_literal: true

# Sends a single tracking event to Umami. Analytics must never affect the
# request it came from, so failures are logged and the job is dropped.
class UmamiEventJob < ApplicationJob
  queue_as :default

  def perform(payload)
    client = Rails.application.config.umami_client
    return if client.blank?

    client.send_event(payload)
  rescue => e
    Rails.logger.error("Failed to track Umami event: #{e.class}: #{e.message}")
  end
end
