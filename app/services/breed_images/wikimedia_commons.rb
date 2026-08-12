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

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    def self.call(...) = new(...).call

    def initialize(breed, limit: 3)
      @breed = breed
      @limit = limit
    end

    def call
      pages.filter_map { |page| candidate_from(page) }.first(@limit)
    end

    private

    # Ask for more pages than needed: some are drawings, diagrams or badly
    # licensed and get dropped below.
    def pages
      response = get(search_uri)
      body = JSON.parse(response.body)

      body.dig("query", "pages")&.values.to_a
    rescue JSON::ParserError => e
      raise Downloader::Error, "unparseable response from Commons: #{e.message}"
    end

    def search_uri
      uri = URI.parse(ENDPOINT)
      uri.query = URI.encode_www_form(
        action: "query",
        format: "json",
        formatversion: 1,
        generator: "search",
        gsrsearch: "filetype:bitmap #{@breed.name} dog",
        gsrnamespace: FILE_NAMESPACE,
        gsrlimit: @limit * 4,
        prop: "imageinfo",
        iiprop: "url|mime|size|extmetadata"
      )
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

      metadata = info["extmetadata"].to_h
      license = value_of(metadata, "LicenseShortName")
      return if license.blank? || license.match?(REJECTED_LICENSES)

      Candidate.new(
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
