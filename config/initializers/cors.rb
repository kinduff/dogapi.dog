# frozen_string_literal: true

# The API is read-only, so only safe methods are exposed cross-origin.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/api/*", headers: :any, methods: %i[get head options]
    resource "/api-docs/*", headers: :any, methods: %i[get head options]
    # A browser-based MCP client reads the card before it connects, and
    # revalidates it by ETag.
    resource "/mcp/server-card", headers: :any, methods: %i[get head options], expose: %w[ETag]
    resource "/.well-known/mcp/server-card.json", headers: :any, methods: %i[get head options], expose: %w[ETag]
  end
end
