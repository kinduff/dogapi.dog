# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.6"

gem "aws-sdk-s3", "~> 1.229", require: false
gem "bootsnap", "~> 1.25"
gem "groupdate", "~> 6.8"
gem "image_processing", "~> 1.14"
gem "jbuilder", "~> 2.15"
gem "jsonapi.rb", "~> 2.0"
gem "pg", "~> 1.4"
gem "pg_search", "~> 2.3"
gem "puma", "~> 8.0"
gem "rack-attack", "~> 6.6"
gem "rack-cors", "~> 3.0", require: "rack/cors"
gem "rails", "~> 8.1"
gem "ransack", "~> 4.4"
gem "redis", "~> 6.0"
gem "rswag", "~> 2.8"
gem "sassc-rails", "~> 2.1"
gem "sidekiq", "~> 8.1"
gem "sprockets-rails", "~> 3.4"
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]
gem "umami-ruby", "~> 0.1.3"

group :development, :test do
  gem "debug", "~> 1.11", platforms: %i[mri mingw x64_mingw]
  gem "factory_bot_rails", "~> 6.2"
  gem "rspec-rails", "~> 8.0"
  gem "standard", "~> 1.56"
end

group :development do
  gem "rack-mini-profiler", "~> 4.0"
  gem "web-console", "~> 4.3"
end

group :test do
  gem "shoulda-matchers", "~> 7.0"
  gem "simplecov", "~> 1.1", require: false
  gem "sqlite3", "~> 2.9"
end
