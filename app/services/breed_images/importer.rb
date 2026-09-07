# frozen_string_literal: true

module BreedImages
  # Turns the candidates an adapter found into stored, attributed images.
  #
  # Re-running it for a breed is a no-op: candidates already imported are
  # skipped by their source id, and files that are byte for byte identical to
  # one the breed already has are skipped by checksum.
  class Importer
    Result = Struct.new(:imported, :skipped, :errors) do
      def summary
        "#{imported.size} imported, #{skipped.size} skipped, #{errors.size} failed"
      end
    end

    # Wikimedia rate limits clients that pull files back to back, and a breed
    # with several candidates would otherwise download them with no gap at all.
    def self.download_delay = ENV.fetch("IMAGE_DOWNLOAD_DELAY", "0.5").to_f

    def self.call(...) = new(...).call

    def initialize(breed, source: DEFAULT_SOURCE, limit: 3)
      @breed = breed
      # Raises on an unknown source, which is a caller mistake, not an import
      # failure to be collected.
      @adapter = BreedImages.adapter_for(source)
      @limit = limit
      @result = Result.new(imported: [], skipped: [], errors: [])
    end

    # `limit` is how many images the breed should end up with, not how many
    # candidates to try. Candidates that are already stored, that duplicate a
    # file, that fail to download or that fall below the quality floor do not
    # count, so the source is walked until the breed has enough or the source
    # runs out.
    def call
      missing = @limit - @breed.breed_images.count
      return @result if missing < 1

      attempted = 0

      candidates.each do |candidate|
        break if @result.imported.size >= missing

        sleep self.class.download_delay if attempted.positive?
        attempted += 1

        import(candidate)
      end

      @result
    end

    private

    def candidates
      @adapter.new(@breed, limit: @limit).candidates
    rescue Downloader::Error => e
      @result.errors << "#{@breed.name}: #{e.message}"
      []
    end

    def import(candidate)
      return @result.skipped << candidate.source_id if already_imported?(candidate)

      Downloader.call(candidate.source_url) do |io, content_type|
        attach(candidate, io, content_type)
      end
    rescue Downloader::Error, ActiveRecord::RecordInvalid => e
      @result.errors << "#{@breed.name} (#{candidate.source_id}): #{e.message}"
    end

    def already_imported?(candidate)
      BreedImage.exists?(source: candidate.source, source_id: candidate.source_id)
    end

    def attach(candidate, io, content_type)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: candidate.filename.presence || File.basename(candidate.source_url),
        content_type: content_type
      )

      if duplicate_checksum?(blob)
        blob.purge
        return @result.skipped << candidate.source_id
      end

      # Fills in width and height, which the record validates on. Commons is
      # asked for them too, but a manual entry has nobody to ask.
      blob.analyze unless blob.analyzed?

      unless decodable?(blob)
        blob.purge
        return @result.errors << "#{@breed.name} (#{candidate.source_id}): file is corrupt or truncated"
      end

      breed_image = @breed.breed_images.build(candidate.to_attributes.merge(position: next_position))
      breed_image.file.attach(blob)

      unless breed_image.save
        blob.purge
        raise ActiveRecord::RecordInvalid, breed_image
      end

      @result.imported << breed_image if preprocess(breed_image)
    end

    # libvips tolerates a broken file by default: a truncated JPEG analyzes
    # fine, since the header still carries its dimensions, and may even come
    # out of the variants as a picture with a grey bottom half. Only a strict
    # decode of the whole file tells the two apart.
    def decodable?(blob)
      blob.open { |file| Vips::Image.new_from_file(file.path, fail: true).avg }
      true
    rescue Vips::Error
      false
    end

    # The same photo can surface twice under different Commons titles.
    def duplicate_checksum?(blob)
      @breed.breed_images.with_files.any? do |existing|
        existing.file.attached? && existing.file.blob.checksum == blob.checksum
      end
    end

    def next_position
      @next_position = (@next_position || @breed.breed_images.maximum(:position).to_i) + 1
    end

    # Build the variants now so the first API request does not pay for them.
    # A file that fails here (a truncated JPEG, say, which still carries its
    # dimensions in the header) would fail again on every request that falls
    # back to processing on demand, so it is dropped instead of kept.
    def preprocess(breed_image)
      BreedImage::VARIANTS.each_key { |name| breed_image.file.variant(name).processed }
      true
    rescue => e
      breed_image.destroy
      @result.errors << "#{@breed.name} (#{breed_image.source_id}): variant processing failed, dropped: #{e.message}"
      false
    end
  end
end
