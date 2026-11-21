# frozen_string_literal: true

require "query_redirector"
# require 'sidekiq/web'

Rails.application.routes.draw do
  mount Rswag::Api::Engine => "/api-docs"
  # mount Sidekiq::Web => '/admin/sidekiq'

  get "up" => "rails/health#show", :as => :rails_health_check

  root to: "pages#index"
  get "/terms", to: "pages#terms", as: :terms
  get "/docs", to: "pages#docs", as: :docs
  get "/teach", to: "pages#teach", as: :teach
  # A breed page is linked by the slug its name parameterizes to, so fixing a
  # misspelled name moves the page. Ahead of the resource, which would answer
  # for the old slug with a 404 of its own.
  get "/breeds/bavarian-mountain-scent-houn",
    to: redirect("/breeds/bavarian-mountain-scent-hound", status: 301)

  resources :breeds, only: %i[index show]
  resources :groups, only: %i[index show]

  # The demo and the gallery both became the breeds pages.
  get "/demo", to: redirect("/breeds", status: 301)
  get "/images", to: redirect("/breeds", status: 301)
  get "/sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: {format: :xml}
  get "/llms.txt", to: "llms#show", as: :llms, defaults: {format: :text}
  # How an agent gets access: it does not need to. See AuthController.
  get "/auth.md", to: "auth#show", as: :auth, defaults: {format: :md}
  # The list of APIs and where each one is described, RFC 9727.
  get "/.well-known/api-catalog", to: "api_catalogs#show", as: :api_catalog
  # Model Context Protocol, streamable HTTP transport, stateless.
  match "/mcp", to: "mcp#handle", via: %i[get post delete], as: :mcp
  # The server card: who the MCP server is and where to connect, readable
  # before connecting. The first address is the one the specification
  # reserves, the second is where older discovery tools look.
  get "/mcp/server-card", to: "mcp_server_cards#show", as: :mcp_server_card
  get "/.well-known/mcp/server-card.json", to: "mcp_server_cards#well_known", as: :well_known_mcp_server_card
  get "/docs/api-v1", to: "pages#api_v1", as: :api_v1
  get "/docs/api-v2", to: "pages#api_v2", as: :api_v2

  namespace :api do
    # get '/facts', to: redirect(QueryRedirector.new('/api/v1/facts'))

    get "/facts", to: "v1/facts#index"

    namespace :v1 do
      resources :facts, only: :index
    end

    namespace :v2 do
      resources :facts, only: :index
      resources :breeds, only: %i[index show] do
        # Redirects to an image file instead of returning JSON, so an <img>
        # tag can point straight at the API.
        get :image, on: :member
        get :image, on: :collection, action: :random_image
      end
      resources :groups, only: %i[index show]
    end
  end
end
