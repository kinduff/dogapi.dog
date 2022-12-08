# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

gem 'active_model_serializers', '~> 0.10'
gem 'ahoy_matey', '~> 4.1'
gem 'bootsnap', '~> 1.15', require: false
gem 'chartkick', '~> 4.2'
gem 'groupdate', '~> 6.1'
gem 'jbuilder', '~> 2.11'
gem 'jsonapi.rb', '~> 2.0'
gem 'pg', '~> 1.4'
gem 'puma', '~> 5.6'
gem 'rack-attack', '~> 6.6'
gem 'rack-cors', '~> 1.1', require: 'rack/cors'
gem 'rails', '~> 7.0'
gem 'ransack', '~> 3.2'
gem 'redis', '~> 4.8'
gem 'rswag', '~> 2.8'
gem 'sassc-rails', '~> 2.1'
gem 'sidekiq', '~> 7.0'
gem 'sprockets-rails', '~> 3.4'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

group :development, :test do
  gem 'debug', '~> 1.6', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails', '~> 6.2'
  gem 'rspec-rails', '~> 6.0'
end

group :development do
  gem 'rack-mini-profiler', '~> 3.0'
  gem 'web-console', '~> 4.2'
end
