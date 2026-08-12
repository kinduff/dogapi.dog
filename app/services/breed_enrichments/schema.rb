# frozen_string_literal: true

module BreedEnrichments
  # The shape the model must answer in, enforced server side by structured
  # outputs rather than by parsing prose.
  #
  # Only `name`, `sources` and `confidence` are required at the top level.
  # Everything else is optional on purpose: a breed the sources are quiet about
  # should come back with fields missing, not with fields invented to satisfy
  # the schema.
  #
  # Inside an optional object, though, the fields that give it meaning are
  # required — a coat with no type, or a traits block with half the ratings
  # filled in, is not worth serving. The objects are all or nothing, which also
  # keeps the schema under the 24 optional fields structured outputs allows.
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
        "required" => RATINGS.map(&:to_s),
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
            "required" => %w[country],
            "additionalProperties" => false
          },
          "coat" => {
            "type" => "object",
            "properties" => {
              "type" => {"type" => "string", "enum" => COAT_TYPES},
              "length" => {"type" => "string", "enum" => COAT_LENGTHS},
              "colors" => {"type" => "array", "items" => {"type" => "string"}}
            },
            "required" => %w[type length colors],
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
              "required" => %w[url title],
              "additionalProperties" => false
            }
          },
          # Facts that contradict what is already stored. Recorded for a human
          # to look at; never written to the breed. A list rather than an
          # object so each correction carries its own reason.
          "corrections" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "properties" => {
                "field" => {"type" => "string", "enum" => %w[life male_weight female_weight]},
                "min" => {"type" => "number"},
                "max" => {"type" => "number"},
                "note" => {"type" => "string"}
              },
              "required" => %w[field min max note],
              "additionalProperties" => false
            }
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
