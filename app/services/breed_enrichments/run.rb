# frozen_string_literal: true

module BreedEnrichments
  # Research one breed, check the answer, write what survives.
  #
  # This is what the rake tasks call. Re-running it for a breed that already
  # has the columns filled in changes nothing unless `overwrite` is asked for.
  class Run
    def self.call(...) = new(...).call

    def initialize(breed, model: BreedEnrichments.model, dry_run: false, overwrite: false, agent: nil)
      @breed = breed
      @model = model
      @dry_run = dry_run
      @overwrite = overwrite
      @agent = agent || Agent.new(breed, model: model)
    end

    def call
      answer = @agent.call
      validation = Validator.call(@breed, answer.attributes)

      Applier.call(
        @breed,
        validation,
        raw: answer.attributes,
        model: @model,
        dry_run: @dry_run,
        overwrite: @overwrite
      )
    end
  end
end
