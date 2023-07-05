# frozen_string_literal: true

FactoryBot.define do
  factory :breed do
    name { "MyString" }
    description { "MyText" }
    association :group
  end
end
