# frozen_string_literal: true

# Where the APIs are, for a program that has only been given the domain: one
# entry per version, each pointing at its OpenAPI document, its docs page and
# the health check. Format described in RFC 9727.
class ApiCatalogsController < ApplicationController
  # Newest first, which is also the order a reader should consider them in.
  VERSIONS = %w[v2 v1].freeze
  PROFILE = "https://www.rfc-editor.org/info/rfc9727"
  CONTENT_TYPE = %(application/linkset+json; profile="#{PROFILE}")
  # The list only changes when a version is added, which takes a deploy.
  CACHE_MAX_AGE = 1.hour

  def show
    expires_in CACHE_MAX_AGE, public: true
    # The RFC asks that a HEAD request can find the catalog from its headers.
    response.headers["Link"] = %(<#{api_catalog_path}>; rel="api-catalog")

    render json: {linkset: VERSIONS.map { |version| entry(OpenapiDocument.load(version)) }},
      content_type: CONTENT_TYPE
  end

  private

  def entry(document)
    {
      :anchor => "#{request.base_url}/api/#{document.version}",
      "service-desc" => [{href: request.base_url + document.document_path, type: "application/json"}],
      "service-doc" => [{href: "#{request.base_url}/docs/api-#{document.version}", type: "text/html"}],
      :status => [{href: request.base_url + rails_health_check_path}]
    }
  end
end
