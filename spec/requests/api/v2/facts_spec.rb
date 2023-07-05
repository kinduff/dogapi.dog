# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "facts", swagger_doc: "v2/swagger.json" do
  path "/facts" do
    get("list facts") do
      tags "Facts"
      response(200, "successful") do
        consumes "application/json"

        parameter name: :limit, in: :query, type: :integer, required: false

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
