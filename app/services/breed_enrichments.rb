# frozen_string_literal: true

# Fills in the breed attributes nobody has typed in by hand, by asking a model
# that can search the web and made to answer in a fixed shape.
#
# Nothing here writes to a breed directly. An agent run produces a payload, the
# validator throws out anything implausible, and only then does the applier
# touch the record — with the whole exchange kept in `breed_enrichments` so a
# surprising value can be traced back to the answer that produced it.
module BreedEnrichments
  DEFAULT_MODEL = "claude-sonnet-5"

  # Ratings are all on the same 1 to 5 scale, so the schema and the validator
  # can treat them as one group.
  RATINGS = Breed::RATINGS

  COAT_TYPES = %w[smooth short medium long wire curly double hairless corded].freeze
  COAT_LENGTHS = %w[hairless short medium long].freeze
  REGISTRIES = %w[AKC FCI UKC KC CKC ANKC NZKC].freeze
  CONFIDENCES = %w[high medium low].freeze

  class Error < StandardError; end

  # Both are read at call time rather than at boot, so a rake task can point a
  # run at a different model without touching the code.
  def self.model = ENV.fetch("ENRICHMENT_MODEL", DEFAULT_MODEL)

  def self.client
    raise Error, "ANTHROPIC_API_KEY is not set" if ENV["ANTHROPIC_API_KEY"].blank?

    Anthropic::Client.new
  end
end
