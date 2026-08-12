# frozen_string_literal: true

FactoryBot.define do
  factory :breed_enrichment do
    association :breed
    model { "claude-sonnet-5" }
    confidence { "high" }
    payload { {"male_height" => {"min" => 55, "max" => 61}} }
    raw_response { {"name" => "Akita"} }
  end
end
