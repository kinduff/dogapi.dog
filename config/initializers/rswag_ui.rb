# frozen_string_literal: true

Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "API V1 Docs"
  c.openapi_endpoint "/api-docs/v2/swagger.yaml", "API V2 Docs"
end
