# frozen_string_literal: true

require "query_redirector"
# require 'sidekiq/web'

Rails.application.routes.draw do
  mount Rswag::Api::Engine => "/api-docs"
  # mount Sidekiq::Web => '/admin/sidekiq'

  root to: "pages#index"
  get "/terms", to: "pages#terms", as: :terms
  get "/stats", to: "pages#stats", as: :stats
  get "/docs", to: "pages#docs", as: :docs
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
      resources :breeds, only: %i[index show]
      resources :groups, only: %i[index show]
    end
  end
end
