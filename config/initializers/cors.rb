# frozen_string_literal: true

# The API is read-only, so only safe methods are exposed cross-origin.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/api/*", headers: :any, methods: %i[get head options]
    resource "/api-docs/*", headers: :any, methods: %i[get head options]
  end
end
