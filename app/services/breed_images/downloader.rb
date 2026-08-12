# frozen_string_literal: true

require "net/http"

module BreedImages
  # Fetches a remote file into a tempfile, refusing anything that is too big,
  # too slow, or not an image. Everything it downloads comes from a URL an
  # adapter produced, never from user input.
  class Downloader
    Error = Class.new(StandardError)

    MAX_REDIRECTS = 3
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # The block goes to `#call`, not to the constructor, so it cannot be
    # forwarded wholesale.
    def self.call(*args, **options, &block) = new(*args, **options).call(&block)

    def initialize(url, max_bytes: BreedImage::MAX_BYTE_SIZE)
      @url = url
      @max_bytes = max_bytes
    end

    # Yields (io, content_type) and returns whatever the block returns.
    def call(&block)
      response = get(URI.parse(@url))

      content_type = response.content_type.to_s.split(";").first
      unless BreedImage::CONTENT_TYPES.include?(content_type)
        raise Error, "unsupported content type #{content_type.presence || "(none)"} at #{@url}"
      end

      body = response.body.to_s
      raise Error, "empty body at #{@url}" if body.empty?
      raise Error, "#{body.bytesize} bytes exceeds the #{@max_bytes} byte limit at #{@url}" if body.bytesize > @max_bytes

      StringIO.open(body) { |io| block.call(io, content_type) }
    rescue URI::InvalidURIError, IOError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "#{e.class}: #{e.message} while downloading #{@url}"
    end

    private

    def get(uri, redirects_left = MAX_REDIRECTS)
      raise Error, "#{uri.scheme.inspect} is not an http(s) url" unless %w[http https].include?(uri.scheme)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request_for(uri)) }

      case response
      when Net::HTTPSuccess
        # Trust the advertised length only to bail out early; the body is
        # checked for real once it has been read.
        if response["content-length"].to_i > @max_bytes
          raise Error, "content-length #{response["content-length"]} exceeds the #{@max_bytes} byte limit at #{uri}"
        end

        response
      when Net::HTTPRedirection
        raise Error, "too many redirects from #{@url}" if redirects_left.zero?

        get(URI.join(uri.to_s, response["location"]), redirects_left - 1)
      else
        raise Error, "#{response.code} #{response.message} for #{uri}"
      end
    end

    def request_for(uri)
      Net::HTTP::Get.new(uri).tap do |request|
        request["User-Agent"] = BreedImages.user_agent
        request["Accept"] = BreedImage::CONTENT_TYPES.join(", ")
      end
    end
  end
end
