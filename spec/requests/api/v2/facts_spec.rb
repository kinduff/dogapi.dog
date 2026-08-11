# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "facts", swagger_doc: "v2/swagger.json" do
  path "/facts" do
    get("list facts") do
      tags "Facts"
      description <<~TEXT.strip
        Returns random dog facts.

        `limit` is clamped to 1..5: anything missing, zero, negative or
        non-numeric returns a single fact, and anything above 5 returns 5.

        Every response is different, so these are sent with
        `Cache-Control: no-store` and must not be cached.
      TEXT
      produces "application/json"

      parameter name: :limit, in: :query, required: false,
        schema: {type: :integer, minimum: 1, maximum: 5, default: 1},
        description: "Number of facts to return (max 5, defaults to 1)"

      response(200, "successful") do
        schema "$ref": "#/components/schemas/FactCollection"

        example "application/json", :example, {
          data: [
            {
              id: "1cd1a16d-6fe1-40ea-9dd2-c21dd0f7c24e",
              type: "fact",
              attributes: {
                body: "Many foot disorders in dogs are caused by long toenails."
              }
            }
          ]
        }

        run_test!
      end
    end
  end
end
