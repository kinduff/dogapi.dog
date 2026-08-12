# frozen_string_literal: true

# A single picture of a breed, imported from an external source together with
# the attribution its licence requires.
class BreedImage < ApplicationRecord
  MAX_BYTE_SIZE = 10.megabytes
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  # Quality floor. Anything smaller is an icon, a badge or a thumbnail rather
  # than a photograph, and would only be upscaled by the largest variant.
  MIN_DIMENSION = 400
  MIN_PIXELS = 300_000

  # Panoramas and tall strips survive a `resize_to_fill` square crop badly, so
  # they are refused rather than shown mangled.
  MAX_ASPECT_RATIO = 2.5

  # The sizes the API exposes. Everything is converted to WebP, which is a
  # third of the bytes of the JPEG originals at the same visual quality.
  VARIANTS = {
    thumb: {resize_to_fill: [200, 200], format: :webp, saver: {quality: 82}},
    medium: {resize_to_limit: [600, 600], format: :webp, saver: {quality: 82}},
    large: {resize_to_limit: [1200, 1200], format: :webp, saver: {quality: 82}}
  }.freeze

  belongs_to :breed

  has_one_attached :file do |attachable|
    VARIANTS.each { |name, options| attachable.variant(name, **options) }
  end

  validates :source, :source_id, :source_url, :license, presence: true
  validates :source_id, uniqueness: {scope: :source}
  validate :file_attached
  validate :file_is_a_supported_image
  validate :file_is_big_enough

  scope :ordered, -> { order(:position, :created_at) }

  # Preloads everything `#url_for` touches, for the serializers: the blob, plus
  # the variant records so that asking for a processed variant is not a query
  # per image per size.
  scope :with_files, lambda {
    with_attached_file.includes(file_attachment: {blob: {variant_records: {image_attachment: :blob}}})
  }

  def url_for(variant = nil)
    return unless file.attached?
    return unless variant.nil? || VARIANTS.key?(variant.to_sym)

    with_url_options do
      url = variant.nil? ? file.url : variant_url(variant.to_sym)

      public_host_url(url)
    end
  end

  def attribution
    {
      author: author,
      license: license,
      license_url: license_url,
      source: source,
      source_url: page_url.presence || source_url
    }
  end

  # Width and height once Active Storage has analyzed the blob. Nil before
  # then, which is why the importer analyzes before saving.
  def dimensions
    return unless file.attached?

    metadata = file.blob.metadata
    width = metadata["width"]
    height = metadata["height"]

    [width, height] if width.to_i.positive? && height.to_i.positive?
  end

  private

  # `variant.processed` costs one query per variant per image, even when the
  # variant records are already loaded, because it looks the record up by
  # digest. Since imports pre-process every size, the loaded records almost
  # always hold the answer; processing is only the fallback.
  def variant_url(name)
    variant = file.variant(name)
    blob = preloaded_variant_record(variant)&.image&.blob

    (blob || variant.processed).url
  end

  def preloaded_variant_record(variant)
    return unless file.blob.association(:variant_records).loaded?

    file.blob.variant_records.find { |record| record.variation_digest == variant.variation.digest }
  end

  # The Disk service builds URLs from a route, so it needs a host. Inside a
  # request Active Storage sets this itself, but rake tasks and jobs do not
  # have one. Bucket services ignore it.
  def with_url_options
    if ActiveStorage::Current.url_options.blank?
      ActiveStorage::Current.url_options = Rails.application.config.x.image_url_options
    end

    yield
  end

  # Buckets are usually fronted by a CDN or custom domain, and Active Storage
  # only knows the bucket's own host. Swapping the host keeps the path, which
  # is all the CDN needs.
  def public_host_url(url)
    host = ENV["S3_PUBLIC_HOST"].presence
    return url if host.nil? || url.blank?

    uri = URI.parse(url)
    replacement = URI.parse(host.start_with?("http") ? host : "https://#{host}")
    uri.scheme = replacement.scheme
    uri.host = replacement.host
    uri.port = replacement.port
    uri.to_s
  rescue URI::InvalidURIError
    url
  end

  def file_attached
    errors.add(:file, "must be attached") unless file.attached?
  end

  # Only checks what is known: a blob that has not been analyzed yet carries no
  # dimensions, and the importer is the one that guarantees they are there.
  def file_is_big_enough
    width, height = dimensions
    return if width.nil?

    if width < MIN_DIMENSION || height < MIN_DIMENSION
      errors.add(:file, "must be at least #{MIN_DIMENSION}px on both sides, got #{width}x#{height}")
    end

    if width * height < MIN_PIXELS
      errors.add(:file, "must be at least #{MIN_PIXELS} pixels, got #{width * height}")
    end

    ratio = [width.to_f / height, height.to_f / width].max
    if ratio > MAX_ASPECT_RATIO
      errors.add(:file, "is too far from square to crop well, got #{width}x#{height}")
    end
  end

  def file_is_a_supported_image
    return unless file.attached?

    unless CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "must be one of #{CONTENT_TYPES.join(", ")}")
    end

    if file.blob.byte_size.to_i > MAX_BYTE_SIZE
      errors.add(:file, "must be smaller than #{MAX_BYTE_SIZE / 1.megabyte}MB")
    end
  end
end
