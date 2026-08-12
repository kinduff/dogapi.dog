# frozen_string_literal: true

module BreedEnrichments
  # The shape the model must answer in, enforced server side by structured
  # outputs rather than by parsing prose.
  #
  # Only `name`, `sources` and `confidence` are required. Everything else is
  # optional on purpose: a breed the sources are quiet about should come back
  # with fields missing, not with fields invented to satisfy the schema.
  module Schema
    RANGE = {
      "type" => "object",
      "properties" => {
        "min" => {"type" => "number"},
        "max" => {"type" => "number"}
      },
      "required" => %w[min max],
      "additionalProperties" => false
    }.freeze

    RATING = {"type" => "integer", "enum" => [1, 2, 3, 4, 5]}.freeze

    def self.rating_properties
      RATINGS.to_h { |name| [name.to_s, RATING] }
    end

    def self.traits
      {
        "type" => "object",
        "properties" => rating_properties.merge(
          "exercise_minutes" => {"type" => "integer"},
          "temperament" => {"type" => "array", "items" => {"type" => "string"}}
        ),
        "required" => [],
        "additionalProperties" => false
      }
    end

    def self.build
      {
        "type" => "object",
        "properties" => {
          "name" => {"type" => "string"},
          "male_height" => RANGE,
          "female_height" => RANGE,
          "origin" => {
            "type" => "object",
            "properties" => {
              "country" => {"type" => "string"},
              "region" => {"type" => "string"},
              "era" => {"type" => "string"}
            },
            "required" => [],
            "additionalProperties" => false
          },
          "coat" => {
            "type" => "object",
            "properties" => {
              "type" => {"type" => "string", "enum" => COAT_TYPES},
              "length" => {"type" => "string", "enum" => COAT_LENGTHS},
              "colors" => {"type" => "array", "items" => {"type" => "string"}}
            },
            "required" => [],
            "additionalProperties" => false
          },
          "traits" => traits,
          "other_names" => {"type" => "array", "items" => {"type" => "string"}},
          "recognized_by" => {
            "type" => "array",
            "items" => {"type" => "string", "enum" => REGISTRIES}
          },
          "sources" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "properties" => {
                "url" => {"type" => "string"},
                "title" => {"type" => "string"}
              },
              "required" => %w[url],
              "additionalProperties" => false
            }
          },
          # Facts that contradict what is already stored. Recorded for a human
          # to look at; never written to the breed.
          "corrections" => {
            "type" => "object",
            "properties" => {
              "life" => RANGE,
              "male_weight" => RANGE,
              "female_weight" => RANGE,
              "note" => {"type" => "string"}
            },
            "required" => [],
            "additionalProperties" => false
          },
          "confidence" => {"type" => "string", "enum" => CONFIDENCES},
          "notes" => {"type" => "string"}
        },
        "required" => %w[name sources confidence],
        "additionalProperties" => false
      }
    end

    def self.to_h = @to_h ||= build.freeze
  end
end
