# frozen_string_literal: true

module BreedEnrichments
  # The disagreements a run reported about the columns enrichment itself never
  # writes: life expectancy and the two weights.
  #
  # These are held back from the run that found them on purpose. The stored
  # ranges are what the API has always served, and a model's second opinion is
  # not on its own grounds to replace them. This is what a person rules on them
  # with: what is still outstanding, and one call to accept one.
  class Corrections
    FIELDS = Breed::PLAUSIBLE_RANGES.keys.freeze

    Correction = Struct.new(:run, :field, :from, :to, :note) do
      def breed = run.breed

      # The stored range already says what the correction asks for, so there is
      # nothing left to rule on. Accepting one turns it into this.
      def settled? = from == to

      def to_s = "#{field}: #{range(from)} -> #{range(to)}"

      private

      def range(value)
        return "empty" if value.blank?

        "#{value["min"]}-#{value["max"]}"
      end
    end

    class << self
      # Every correction still waiting on a decision, newest run first. Only the
      # newest run per breed counts: an older one was answered by the re-run
      # that replaced it.
      def outstanding
        latest_runs.flat_map { |run| for_run(run) }.reject(&:settled?)
      end

      def for_breed(breed)
        run = breed.breed_enrichments.ordered.first
        run ? for_run(run).reject(&:settled?) : []
      end

      # Writes the corrected range onto the breed, and records what it replaced
      # on the run that proposed it, so an accepted correction can be read back
      # and undone.
      #
      # Both writers load the breed again rather than trusting the instance the
      # correction was built from: assigning a value equal to a stale one looks
      # like no change at all to ActiveRecord, and the write is dropped.
      def accept(correction)
        breed = Breed.find(correction.run.breed_id)
        replaced = breed.public_send(correction.field).presence

        Breed.transaction do
          breed.update!(correction.field => correction.to)
          record(correction, replaced)
        end

        correction
      end

      # Puts back every range an accepted correction replaced, newest first so
      # a field corrected twice ends on the value it started at.
      def revert(run)
        accepted = Array(run.payload["accepted_corrections"])
        return [] if accepted.empty?

        breed = Breed.find(run.breed_id)

        Breed.transaction do
          # The columns are `null: false`, so a field that was empty before
          # goes back to the empty object rather than to nothing.
          accepted.reverse_each { |entry| breed.update!(entry["field"] => entry["from"] || {}) }
          run.update!(payload: run.payload.except("accepted_corrections"))
        end

        accepted
      end

      # Runs carrying an accepted correction, for the undo. Written as `->`
      # rather than the `?` containment operator, which ActiveRecord reads as a
      # bind placeholder.
      def accepted_runs
        BreedEnrichment.where("payload -> 'accepted_corrections' IS NOT NULL").includes(:breed).ordered
      end

      private

      def for_run(run)
        Array(run.raw_response["corrections"]).filter_map do |entry|
          field = entry["field"]
          next unless FIELDS.include?(field)

          proposed = proposed_range(entry, field)
          next if proposed.nil?

          Correction.new(run, field, run.breed.public_send(field).presence, proposed, entry["note"])
        end
      end

      # Held to the same bar the validator holds an answer to, since a
      # correction is the same kind of guess arriving by a different door.
      def proposed_range(entry, field)
        min, max = entry.values_at("min", "max").map { |number| number&.to_f }
        return if min.nil? || max.nil? || min > max

        bounds = Breed::PLAUSIBLE_RANGES.fetch(field)
        return unless bounds.cover?(min) && bounds.cover?(max)

        {"min" => min.round, "max" => max.round}
      end

      def record(correction, replaced)
        run = correction.run
        applied = Array(run.payload["accepted_corrections"])

        run.update!(
          payload: run.payload.merge(
            "accepted_corrections" => applied + [{
              "field" => correction.field,
              "from" => replaced,
              "to" => correction.to,
              "at" => Time.current.iso8601
            }]
          )
        )
      end

      # One run per breed, the newest, and only the ones that proposed
      # something. Loaded in a single pass rather than per breed.
      def latest_runs
        BreedEnrichment
          .where(id: BreedEnrichment.select("DISTINCT ON (breed_id) id").order(:breed_id, created_at: :desc))
          .includes(:breed)
          .ordered
          .reject { |run| run.raw_response["corrections"].blank? }
      end
    end
  end
end
