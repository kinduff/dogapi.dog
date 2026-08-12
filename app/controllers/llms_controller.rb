# frozen_string_literal: true

# The site in one page, for a model reading it rather than a person browsing
# it: what the API holds, where every endpoint is, and what to read next.
# Format described at https://llmstxt.org.
class LlmsController < ApplicationController
  # Newest first, which is also the order a reader should consider them in.
  VERSIONS = %w[v2 v1].freeze

  def show
    @counts = DataCounts.call
    @documents = VERSIONS.map { |version| OpenapiDocument.load(version) }

    respond_to do |format|
      format.text
    end
  end
end
