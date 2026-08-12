# frozen_string_literal: true

require "net/http"

module BreedImages
  # Searches Wikimedia Commons for pictures of a breed.
  #
  # Commons is the only large dog photo collection whose licences allow
  # re-hosting the files on our own bucket, as long as the author and licence
  # travel with the image. Both come back in the `extmetadata` block.
  class WikimediaCommons
    ENDPOINT = "https://commons.wikimedia.org/w/api.php"
    SOURCE = "wikimedia_commons"

    # File namespace on Commons.
    FILE_NAMESPACE = 6

    # Licences that either forbid re-use or require case by case judgement.
    REJECTED_LICENSES = /fair use|non-?free|no license|unknown/i

    # Commons holds far more than photographs. Titles saying so are cheaper to
    # reject than pixels are to download.
    REJECTED_TITLES = /\b(logo|icon|map|diagram|chart|graph|coat[ _]of[ _]arms|stamp|banner|
                        seal|flag|silhouette|skeleton|x-?ray|poster|cover|screenshot)\b/xi

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # How many search results to ask for at a time, and how many pages of them
    # to walk before accepting that Commons has nothing else to offer.
    PAGE_SIZE = 20
    MAX_PAGES = 5

    def self.call(...) = new(...).call

    def initialize(breed, limit: 3)
      @breed = breed
      @limit = limit
    end

    def call
      candidates.first(@limit)
    end

    # Every usable result Commons has, the next page fetched only when the
    # caller asks for more. Most of a search is drawings, diagrams and badly
    # licensed files, so a caller that needs five may have to look at forty.
    #
    # `to_enum` rather than `Enumerator.new`: the latter runs its block in a
    # Fiber, and a constant autoloaded for the first time inside one raises
    # NameError in development.
    def candidates
      to_enum(:each_candidate)
    end

    def each_candidate
      continuation = nil

      MAX_PAGES.times do
        body = search(continuation)
        pages = body.dig("query", "pages")&.values.to_a

        pages.each do |page|
          candidate = candidate_from(page)
          yield candidate if candidate
        end

        # Commons hands back the cursor for the next page, and omits it once
        # the results are exhausted.
        continuation = body["continue"]
        break if continuation.blank?
      end
    end

    private

    def search(continuation)
      response = get(search_uri(continuation))

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Downloader::Error, "unparseable response from Commons: #{e.message}"
    end

    def search_uri(continuation = nil)
      uri = URI.parse(ENDPOINT)
      params = {
        action: "query",
        format: "json",
        formatversion: 1,
        generator: "search",
        gsrsearch: "filetype:bitmap #{@breed.name} dog",
        gsrnamespace: FILE_NAMESPACE,
        gsrlimit: PAGE_SIZE,
        prop: "imageinfo",
        # `size` covers width and height as well as byte size, which is what
        # the quality filter below needs.
        iiprop: "url|mime|size|extmetadata"
      }
      params.merge!(continuation.symbolize_keys) if continuation.present?

      uri.query = URI.encode_www_form(params)
      uri
    end

    def get(uri)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request_for(uri)) }

      return response if response.is_a?(Net::HTTPSuccess)

      raise Downloader::Error, "#{response.code} #{response.message} from Commons"
    rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, IOError => e
      raise Downloader::Error, "#{e.class}: #{e.message} while querying Commons"
    end

    def request_for(uri)
      Net::HTTP::Get.new(uri).tap do |request|
        request["User-Agent"] = BreedImages.user_agent
        request["Accept"] = "application/json"
      end
    end

    def candidate_from(page)
      info = page["imageinfo"]&.first
      return if info.nil?
      return unless BreedImage::CONTENT_TYPES.include?(info["mime"])
      return if page["title"].to_s.match?(REJECTED_TITLES)
      return if info["size"].to_i > BreedImage::MAX_BYTE_SIZE
      return unless big_enough?(info)

      metadata = info["extmetadata"].to_h
      license = value_of(metadata, "LicenseShortName")
      return if license.blank? || license.match?(REJECTED_LICENSES)

      BreedImages::Candidate.new(
        source: SOURCE,
        source_id: page["title"],
        source_url: info["url"],
        page_url: info["descriptionurl"],
        author: value_of(metadata, "Artist"),
        license: license,
        license_url: value_of(metadata, "LicenseUrl"),
        filename: filename_for(page["title"], info["url"])
      )
    end

    # The same floor the model enforces, applied to what Commons reports so a
    # too small file is never fetched in the first place.
    def big_enough?(info)
      width = info["width"].to_i
      height = info["height"].to_i
      return false if width.zero? || height.zero?
      return false if width < BreedImage::MIN_DIMENSION || height < BreedImage::MIN_DIMENSION
      return false if width * height < BreedImage::MIN_PIXELS

      [width.to_f / height, height.to_f / width].max <= BreedImage::MAX_ASPECT_RATIO
    end

    # extmetadata values are HTML fragments: the artist is usually a link.
    def value_of(metadata, key)
      raw = metadata.dig(key, "value")
      return if raw.blank?

      ActionController::Base.helpers.strip_tags(raw).squish.presence
    end

    def filename_for(title, url)
      name = title.to_s.delete_prefix("File:").presence || File.basename(URI.parse(url).path)

      name.tr(" ", "_")
    end
  end
end
