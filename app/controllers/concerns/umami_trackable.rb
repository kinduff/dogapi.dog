# frozen_string_literal: true

module UmamiTrackable
  extend ActiveSupport::Concern

  included do
    after_action :track_api_request
  end

  private

  def track_api_request
    Rails.logger.debug "Umami enabled: #{umami_enabled?}"
    return unless umami_enabled?

    event_data = build_event_data

    # The poors man sidekiq
    Thread.new do
      begin
        Rails.application.config.umami_client.send_event(event_payload(event_data))
        Rails.logger.debug "Umami event tracked: #{event_data[:event_name]}"
      rescue StandardError => e
        Rails.logger.error "Failed to track Umami event: #{e.message}"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Error preparing Umami tracking: #{e.message}"
  end

  def umami_enabled?
    Rails.application.config.umami_client.present? &&
      Rails.application.config.umami_website_id.present?
  end

  def build_event_data
    {
      event_name: "api_request",
      endpoint: request.path,
      method: request.method,
      controller: controller_name,
      action: action_name,
      api_version: extract_api_version,
      status: response.status,
      ip_address: request.remote_ip,
      referer: request.referer
    }
  end

  def event_payload(data)
    {
      hostname: request.host,
      language: extract_language,
      referrer: request.referer || "",
      screen: "",
      title: "API: #{data[:endpoint]}",
      url: request.original_url,
      website: Rails.application.config.umami_website_id,
      name: data[:event_name],
      data: {
        endpoint: data[:endpoint],
        method: data[:method],
        controller: data[:controller],
        action: data[:action],
        api_version: data[:api_version],
        status: data[:status]
      }
    }
  end

  def extract_api_version
    match = request.path.match(/\/api\/v(\d+)/)
    match ? "v#{match[1]}" : "unknown"
  end

  def extract_language
    if request.headers["Accept-Language"]
      request.headers["Accept-Language"].split(",").first&.strip || "en-US"
    else
      "en-US"
    end
  end
end
