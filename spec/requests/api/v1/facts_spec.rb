# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "facts", swagger_doc: "v1/swagger.json" do
  path "/facts" do
    get("list facts") do
      response(200, "successful") do
        consumes "application/json"

        parameter name: :number, in: :query, type: :integer, required: false
        parameter name: :raw, in: :query, type: :boolean, required: false

        example "application/json", :example, {
          facts: ["Two Labradors, Lucky and Flo, were the first dogs known for sniffing out pirated DVDs."],
          success: true
        }

        run_test!
      end
    end
  end
end
