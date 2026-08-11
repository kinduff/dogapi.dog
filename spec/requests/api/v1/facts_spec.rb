# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "facts", swagger_doc: "v1/swagger.json" do
  path "/facts" do
    get("list facts") do
      tags "Facts"
      description <<~TEXT.strip
        Returns random dog facts in the classic (deprecated) format.

        `number` and `limit` are aliases for the same thing and are clamped to
        1..5: anything missing, zero, negative or non-numeric returns a single
        fact, and anything above 5 returns 5.

        With `raw=true` the response is the plain text of one fact rather than
        JSON, and it is a 404 when no facts exist at all.

        Every response is different, so these are sent with
        `Cache-Control: no-store` and must not be cached. New integrations
        should use V2.
      TEXT
      produces "application/json", "text/plain"

      parameter name: :number, in: :query, required: false,
        schema: {type: :integer, minimum: 1, maximum: 5, default: 1},
        description: "Number of facts to return (max 5, defaults to 1)"
      parameter name: :limit, in: :query, required: false,
        schema: {type: :integer, minimum: 1, maximum: 5, default: 1},
        description: "Number of facts to return (max 5, defaults to 1) - alias for 'number'"
      parameter name: :raw, in: :query, required: false,
        schema: {type: :boolean},
        description: "Return plain text instead of JSON"

      response(200, "successful") do
        schema type: :object,
          properties: {
            facts: {
              type: :array,
              items: {type: :string},
              description: "The requested facts, one string each"
            },
            success: {type: :boolean, example: true}
          }

        example "application/json", :example, {
          facts: ["Two Labradors, Lucky and Flo, were the first dogs known for sniffing out pirated DVDs."],
          success: true
        }

        run_test!
      end
    end
  end
end
