# frozen_string_literal: true

require "net/http"

module BreedImages
  # Openverse, which indexes the openly licensed images of Flickr and a dozen
  # other collections.
  #
  # Commons is an archive: its dog pictures are whatever somebody happened to
  # upload. Flickr is where the photographers are, and a lot of that work is
  # CC licensed. The filters below ask only for licences that allow re-hosting
  # and modification, which is what a stored, cropped, re-encoded copy needs.
  class Openverse
    ENDPOINT = "https://api.openverse.org/v1/images/"
    SOURCE = "openverse"

    # Licences that permit commercial use and modification. Anything else
    # cannot be resized into our variants, or served from our bucket.
    LICENSE_TYPE = "commercial,modification"

    # Openverse's own quality signals are thin, so the search is narrowed with
    # what it does expose: photographs, big ones, and nothing tagged as an
    # illustration.
    PAGE_SIZE = 20
    MAX_PAGES = 8

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # Written extended, so a literal space has to be spelled out.
    REJECTED_TITLES = /\b(logo|icon|clip[ ]?art|drawing|illustration|painting|sketch|cartoon|
                         statue|figurine|toy|plush|tattoo|sign|poster)\b/xi

    def self.call(...) = new(...).call

    def initialize(breed, limit: 3)
      @breed = breed
      @limit = limit
    end

    def call
      candidates.first(@limit)
    end

    def candidates
      to_enum(:each_candidate)
    end

    def each_candidate
      (1..MAX_PAGES).each do |page_number|
        body = search(page_number)
        results = body["results"].to_a

        results.each do |result|
          candidate = candidate_from(result)
          yield candidate if candidate
        end

        break if results.size < PAGE_SIZE
      end
    end

    private

    def search(page_number)
      response = get(search_uri(page_number))

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Downloader::Error, "unparseable response from Openverse: #{e.message}"
    end

    def search_uri(page_number)
      uri = URI.parse(ENDPOINT)
      uri.query = URI.encode_www_form(
        q: "#{@breed.name} dog",
        license_type: LICENSE_TYPE,
        category: "photograph",
        size: "large",
        page_size: PAGE_SIZE,
        page: page_number
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

      raise Downloader::Error, "#{response.code} #{response.message} from Openverse"
    rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, IOError => e
      raise Downloader::Error, "#{e.class}: #{e.message} while querying Openverse"
    end

    def request_for(uri)
      Net::HTTP::Get.new(uri).tap do |request|
        request["User-Agent"] = BreedImages.user_agent
        request["Accept"] = "application/json"
      end
    end

    def candidate_from(result)
      return if result["url"].blank?
      return if result["title"].to_s.match?(REJECTED_TITLES)
      return if result["license"].blank?
      return unless big_enough?(result)

      BreedImages::Candidate.new(
        source: SOURCE,
        source_id: result["id"],
        source_url: result["url"],
        page_url: result["foreign_landing_url"].presence || result["url"],
        author: result["creator"].presence,
        license: license_for(result),
        license_url: result["license_url"].presence,
        filename: filename_for(result)
      )
    end

    # Openverse reports dimensions for most results and nothing for a few. An
    # unknown size is let through: the downloader and the model both check the
    # file itself, and refusing here would drop good photographs.
    def big_enough?(result)
      width = result["width"].to_i
      height = result["height"].to_i
      return true if width.zero? || height.zero?
      return false if width < BreedImage::MIN_DIMENSION || height < BreedImage::MIN_DIMENSION
      return false if width * height < BreedImage::MIN_PIXELS

      [width.to_f / height, height.to_f / width].max <= BreedImage::MAX_ASPECT_RATIO
    end

    # The API splits a licence into its short name and version, which read as
    # one thing everywhere they are shown.
    def license_for(result)
      [result["license"].to_s.upcase, result["license_version"].presence].compact.join(" ").squish
    end

    def filename_for(result)
      name = File.basename(URI.parse(result["url"]).path).presence || result["id"]

      name.tr(" ", "_")
    rescue URI::InvalidURIError
      result["id"]
    end
  end
end
