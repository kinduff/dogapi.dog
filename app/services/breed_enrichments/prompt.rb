# frozen_string_literal: true

module BreedEnrichments
  # The instructions, split so the long half never changes between breeds and
  # can therefore be cached across a whole run.
  module Prompt
    SYSTEM = <<~TEXT
      You fill in reference data about dog breeds for a public API.

      Work from sources, not from memory. Search the web for each breed and
      prefer national kennel club breed standards (AKC, FCI, UKC, The Kennel
      Club) over aggregator and pet-shop sites. Every answer must list the
      pages you actually used.

      Rules:

      - Omit a field rather than guess it. A missing field is correct and
        expected; an invented number is a bug that reaches real clients.
      - `origin`, `coat` and `traits` are all or nothing. Leave the whole
        object out unless you can fill in every field it requires.
      - Heights are centimetres at the withers, adult, for the standard variety
        of the breed. Weights are kilograms. Convert from inches or pounds when
        a source uses them, and round to whole numbers.
      - When a breed has several size varieties, describe the standard one and
        say so in `notes`.
      - Ratings run from 1 to 5. They are relative to dogs in general, not to
        the breed's own group: 3 is an average dog. Use the same scale for all
        breeds.
        - energy: how much activity the breed needs to stay settled
        - trainability: how readily it learns and obeys new cues
        - barking: how much noise it makes, unprompted
        - grooming: how much brushing and trimming its coat needs
        - shedding: how much hair it drops
        - drooling: how much it slobbers
        - good_with_children, good_with_dogs, good_with_strangers: typical
          tolerance of each, well socialised
        - apartment_friendly: how well it copes with a small home
      - exercise_minutes is the typical daily total for a healthy adult.
      - temperament is at most six single words or short phrases from the
        sources, not a sentence.
      - recognized_by lists only registries that recognise the breed outright,
        not ones with a provisional or foundation register listing.
      - If a source clearly contradicts the weight or life expectancy the API
        already stores, add an entry to `corrections` naming the field, the
        range the source gives and why you believe it. Do not put corrections
        anywhere else.
      - confidence is `high` when a kennel club standard covers most fields,
        `medium` when you relied on secondary sources, `low` when the breed is
        obscure and the sources disagree. Ratings are always estimates; do not
        let them lift the confidence on their own.

      Answer with the JSON object only.
    TEXT

    def self.user_message(breed)
      <<~TEXT
        Breed: #{breed.name}
        Group: #{breed.group&.name}
        Already stored, for context and for `corrections` only:
          life: #{range(breed.life)} years
          male weight: #{range(breed.male_weight)} kg
          female weight: #{range(breed.female_weight)} kg
          description: #{breed.description}

        Research this breed and return the JSON object.
      TEXT
    end

    def self.range(value)
      min, max = value.to_h.values_at("min", "max")
      return "unknown" if min.nil? || max.nil?

      "#{min}-#{max}"
    end
  end
end
