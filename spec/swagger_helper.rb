# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.swagger_root = Rails.root.join("swagger").to_s
  config.swagger_format = :json
  config.swagger_docs = {
    "v1/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "API V1",
        version: "1.0.0",
        description: "The Dog Facts API allows users to access a collection of dog facts that have been submitted by members of the public. The API is simple to use and provides a variety of options for retrieving dog facts. With the V1 version of the API, users can access dog facts in a variety of formats, including plain text and HTML.",
        termsOfService: "https://dogapi.dog/terms",
        contact: {
          email: "dev@dogapi.dog"
        },
        license: {
          name: "MIT",
          url: "https://github.com/kinduff/dogapi.dog/blob/master/LICENSE"
        }
      },
      servers: [{url: "https://dogapi.dog/api/v1"}]
    },
    "v2/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "API V2",
        version: "1.0.0",
        description: "The Dog API provides a wealth of information on dog breeds, groups, and fun facts. Access and integrate this data into your website or application with our easy-to-use JSON API.",
        termsOfService: "https://dogapi.dog/terms",
        contact: {
          email: "dev@dogapi.dog"
        },
        license: {
          name: "MIT",
          url: "https://github.com/kinduff/dogapi.dog/blob/master/LICENSE"
        }
      },
      servers: [{url: "https://dogapi.dog/api/v2"}]
    }
  }
end
