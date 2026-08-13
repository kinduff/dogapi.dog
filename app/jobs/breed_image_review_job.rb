# frozen_string_literal: true

# Scores one picture, and puts the breed's pictures in order once the last of
# them has been scored.
#
# One job per picture rather than per breed: scoring is a single request whose
# cost is entirely latency, so the useful unit of parallelism is the picture.
# The reordering has to wait for the whole breed, which is why it happens here
# rather than in whatever enqueued the jobs — the last job to finish is the
# only one that knows the breed is done.
class BreedImageReviewJob < ApplicationJob
  queue_as :reviews

  # Rate limits and overloaded responses are worth waiting out. A picture the
  # model cannot read is not.
  retry_on BreedImages::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(breed_image_id, force: false)
    image = BreedImage.find_by(id: breed_image_id)
    return if image.nil?
    return if image.reviewed_at.present? && !force

    result = BreedImages::Reviewer.call(image)
    image.update!(score: result.score, review_notes: result.notes, reviewed_at: Time.current)

    reorder(image.breed)
  end

  private

  # Whichever job finishes last does the reordering; the others see a breed
  # with pictures still waiting and leave it alone. `reorder!` takes a lock, so
  # two jobs finishing together cannot interleave.
  def reorder(breed)
    return if breed.breed_images.where(reviewed_at: nil).exists?

    BreedImages::Reranker.reorder!(breed)
  end
end
