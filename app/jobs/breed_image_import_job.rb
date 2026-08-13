# frozen_string_literal: true

# Imports one breed's images from one source, then hands the breed on to the
# next source if it is still short.
#
# A breed at a time rather than a source at a time: the work is almost entirely
# waiting on somebody else's API, so a hundred breeds can be in flight while
# each one politely works through its own sources in order. The chain is what
# keeps the good sources ahead of the desperate ones — a breed only reaches a
# full text search once its article and its category have been exhausted.
class BreedImageImportJob < ApplicationJob
  queue_as :images

  # A source being down is worth another go later; a breed that has since been
  # deleted is not.
  retry_on BreedImages::Downloader::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(breed_id, source, limit, review: true)
    breed = Breed.find_by(id: breed_id)
    return if breed.nil?

    result = BreedImages::Importer.call(breed, source: source, limit: limit)
    result.errors.each { |error| Rails.logger.warn("import: #{error}") }

    # Only the new images are worth a look: the rest already carry a score.
    result.imported.each { |image| BreedImageReviewJob.perform_later(image.id) } if review

    enqueue_next_source(breed, source, limit, review: review)
  end

  private

  # The next source in the list, and only if the breed still needs pictures.
  def enqueue_next_source(breed, source, limit, review:)
    return if breed.breed_images.count >= limit

    next_source = BreedImages::SOURCE_ORDER[BreedImages::SOURCE_ORDER.index(source).to_i + 1]
    return if next_source.blank?

    self.class.perform_later(breed.id, next_source, limit, review: review)
  end
end
