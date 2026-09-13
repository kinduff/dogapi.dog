# frozen_string_literal: true

module UmamiTrackable
  extend ActiveSupport::Concern

  included do
    after_action :track_api_request
  end

  private

  def track_api_request
    return unless umami_enabled?

    UmamiEventJob.perform_later(event_payload)
  rescue => e
    Rails.logger.error "Error preparing Umami tracking: #{e.message}"
  end

  def umami_enabled?
    Rails.application.config.umami_client.present? &&
      Rails.application.config.umami_website_id.present?
  end

  # Every key in `data` becomes its own event_data row in Umami, indexed six
  # ways over. Endpoint and status are the two anyone has ever queried; method,
  # controller, action and version are all readable from the endpoint string.
  def event_payload
    {
      hostname: request.host,
      language: extract_language,
      referrer: request.referer || "",
      screen: "",
      title: "API: #{request.path}",
      url: request.original_url,
      website: Rails.application.config.umami_website_id,
      name: "api_request",
      data: {
        endpoint: request.path,
        status: response.status
      }
    }
  end

  def extract_language
    if request.headers["Accept-Language"]
      request.headers["Accept-Language"].split(",").first&.strip || "en-US"
    else
      "en-US"
    end
  end
end
