# frozen_string_literal: true

FactoryBot.define do
  factory :fact do
    uuid { SecureRandom.uuid }
    body { "Lorem Ipsum Dolor Sit Amet" }
  end
end
