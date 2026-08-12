# frozen_string_literal: true

require "anthropic"

module BreedEnrichments
  # One breed, one request. The model searches the web itself, so the only
  # thing that comes back here is the finished JSON object.
  class Agent
    # Enough for the searches plus the object; the object alone is around a
    # thousand tokens.
    MAX_TOKENS = 8_000

    # Each search costs money and the breed standards are usually in the first
    # couple of results.
    MAX_SEARCHES = 6

    Result = Struct.new(:attributes, :raw, :usage) do
      def confidence = attributes["confidence"]

      def sources = attributes.fetch("sources", [])
    end

    def self.call(...) = new(...).call

    def initialize(breed, model: BreedEnrichments.model, client: BreedEnrichments.client)
      @breed = breed
      @model = model
      @client = client
    end

    def call
      response = request
      Result.new(attributes: parse(response), raw: response.to_h, usage: response.usage.to_h)
    rescue Anthropic::Errors::Error => e
      raise Error, "#{@model}: #{e.message}"
    end

    private

    def request
      @client.messages.create(
        model: @model,
        max_tokens: MAX_TOKENS,
        # The instructions are identical for every breed in a run, so the
        # cache covers everything up to the breed's own line.
        system_: [{type: "text", text: Prompt::SYSTEM, cache_control: {type: "ephemeral"}}],
        tools: [{type: "web_search_20260209", name: "web_search", max_uses: MAX_SEARCHES}],
        output_config: {effort: :medium, format_: {type: :json_schema, schema: Schema.to_h}},
        messages: [{role: "user", content: Prompt.user_message(@breed)}]
      )
    end

    # Structured outputs put the object in the response text, alongside the
    # search result blocks the tool produced along the way.
    def parse(response)
      raise Error, "#{@breed.name}: refused (#{response.stop_details&.category})" if response.stop_reason == :refusal

      text = response.content.select { |block| block.type == :text }.map(&:text).join.strip
      raise Error, "#{@breed.name}: no text in response (#{response.stop_reason})" if text.empty?

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise Error, "#{@breed.name}: #{e.message}"
    end
  end
end
