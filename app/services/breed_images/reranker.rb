# frozen_string_literal: true

module BreedImages
  # Scores every picture a breed has and puts the best one first.
  #
  # Import order is arrival order: whichever file a source happened to return
  # first ends up as the breed's main image. That is fine for a gallery and
  # wrong for the one picture most clients ask for, so this looks at all of
  # them and orders them by what they actually show.
  #
  # A picture that has already been scored is left alone unless `force` is set,
  # which makes a run over every breed resumable and a re-run cheap.
  class Reranker
    Result = Struct.new(:reviewed, :skipped, :errors, :primary) do
      def summary
        counts = "#{reviewed.size} reviewed, #{skipped.size} skipped, #{errors.size} failed"
        best = primary&.score
        return counts if best.nil?

        "#{counts}, best #{best}/10"
      end
    end

    # A model that is asked to look at pictures back to back gets rate limited
    # like anything else.
    def self.review_delay = ENV.fetch("IMAGE_REVIEW_DELAY", "0").to_f

    def self.call(...) = new(...).call

    def initialize(breed, force: false, model: BreedImages.review_model, client: BreedImages.review_client)
      @breed = breed
      @force = force
      @model = model
      @client = client
      @result = Result.new(reviewed: [], skipped: [], errors: [], primary: nil)
    end

    def call
      images = @breed.breed_images.with_files.to_a
      return @result if images.empty?

      images.each_with_index do |image, index|
        next @result.skipped << image if skip?(image)

        sleep self.class.review_delay if index.positive? && self.class.review_delay.positive?
        review(image)
      end

      reorder(images)
      @result
    end

    private

    def skip?(image)
      !@force && image.reviewed_at.present?
    end

    def review(image)
      result = Reviewer.call(image, model: @model, client: @client)

      image.update!(score: result.score, review_notes: result.notes, reviewed_at: Time.current)
      @result.reviewed << image
    rescue Error, ActiveRecord::RecordInvalid => e
      @result.errors << "#{@breed.name} (#{image.source_id}): #{e.message}"
    end

    # Best score first; a picture nobody could score keeps its place behind the
    # ones that were, rather than being promoted by an empty column. Ties fall
    # back to the order they were imported in, so a rerun is stable.
    def reorder(images)
      ordered = images.sort_by.with_index do |image, index|
        [image.score.nil? ? 1 : 0, -image.score.to_i, index]
      end

      BreedImage.transaction do
        ordered.each_with_index do |image, index|
          image.update_column(:position, index + 1) unless image.position == index + 1
        end
      end

      @result.primary = ordered.first
    end
  end
end
