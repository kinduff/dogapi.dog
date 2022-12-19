# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.swagger_root = Rails.root.join('swagger').to_s
  config.swagger_format = :json
  config.swagger_docs = {
    'v1/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: '1.0.0',
        description: 'The Stratonauts Dog Facts API allows users to access a collection of dog facts that have been submitted by members of the public. The API is simple to use and provides a variety of options for retrieving dog facts. With the V1 version of the API, users can access dog facts in a variety of formats, including plain text and HTML.',
        termsOfService: 'https://dogapi.dog/terms',
        contact: {
          email: 'dev@dogapi.dog'
        },
        license: {
          name: 'MIT',
          url: 'https://github.com/kinduff/dogapi.dog/blob/master/LICENSE'
        }
      },
      servers: [{ url: 'https://dogapi.dog/api/v1' }]
    },
    'v2/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'API V2',
        version: '1.0.0',
        description: "The Stratonauts Dog Facts API is a powerful and flexible tool for accessing a collection of dog facts. This V2 version of the API follows the JSON API specification, allowing for seamless integration with your application. With the V2 API, users can access dog facts in a structured JSON format, making it easy to work with the data and build powerful applications. Whether you're building a website or a mobile app, the Stratonauts Dog Facts API can help you quickly and easily access a wide range of dog facts.",
        termsOfService: 'https://dogapi.dog/terms',
        contact: {
          email: 'dev@dogapi.dog'
        },
        license: {
          name: 'MIT',
          url: 'https://github.com/kinduff/dogapi.dog/blob/master/LICENSE'
        }
      },
      servers: [{ url: 'http://localhost:3000/api/v2' }]
    }
  }
end
