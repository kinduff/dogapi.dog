# frozen_string_literal: true

module BreedEnrichments
  # Writes a validated payload onto a breed and records the run either way.
  #
  # Enrichment only ever fills in the columns added for it. The name,
  # description, group, weights and life expectancy that were already there are
  # left alone — a disagreement about those arrives as `corrections`, which is
  # stored for a human to read and never applied.
  class Applier
    COLUMNS = %w[male_height female_height origin coat traits other_names recognized_by sources].freeze

    def self.call(...) = new(...).call

    # `raw` is what the model actually answered, kept whole so a wrong value can
    # be traced back past the validator.
    def initialize(breed, validation, raw:, usage: {}, model: BreedEnrichments.model, dry_run: false, overwrite: false)
      @breed = breed
      @validation = validation
      @raw = raw
      @usage = usage
      @model = model
      @dry_run = dry_run
      @overwrite = overwrite
    end

    # Returns the enrichment record, unsaved on a dry run.
    def call
      changes = @validation.valid? ? apply : {}
      record = build_record(changes)

      unless @dry_run
        Breed.transaction do
          @breed.save!
          record.save!
        end
      end

      record
    end

    private

    def build_record(changes)
      @breed.breed_enrichments.new(
        model: @model,
        confidence: @raw["confidence"],
        # What the run cost, kept alongside what it produced so a catalogue
        # wide run can be priced afterwards rather than estimated.
        payload: @validation.payload.merge("changes" => changes, "usage" => @usage),
        raw_response: @raw,
        rejections: rejections,
        applied_at: changes.present? ? Time.current : nil
      )
    end

    def rejections
      return @validation.rejections if @validation.valid?

      @validation.rejections + [{"field" => "*", "reason" => @validation.fatal}]
    end

    # A column is filled in only if it is empty, unless the caller asked to
    # overwrite: re-running a whole catalogue should not silently rewrite
    # values somebody has since corrected by hand.
    def apply
      changes = {}

      COLUMNS.each do |column|
        value = @validation.payload[column]
        next if value.blank?

        current = @breed.public_send(column)
        next if current.present? && !@overwrite

        changes[column] = {"from" => current, "to" => value}
        @breed.public_send(:"#{column}=", value)
      end

      return changes if changes.empty?

      @breed.enriched_at = Time.current
      @breed.enrichment_model = @model
      changes
    end
  end
end
