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

    # Wikimedia throttles clients that pull files back to back. When it says so
    # with a 429, or when its servers are briefly unavailable, waiting and
    # trying again is the documented way through.
    RETRY_STATUSES = [429, 503].freeze
    MAX_RETRIES = 4
    BASE_BACKOFF = 2
    MAX_BACKOFF = 60

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

    def get(uri, redirects_left = MAX_REDIRECTS, attempt = 0)
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

        get(URI.join(uri.to_s, response["location"]), redirects_left - 1, attempt)
      when ->(r) { RETRY_STATUSES.include?(r.code.to_i) }
        raise Error, "#{response.code} after #{attempt} retries for #{uri}" if attempt >= MAX_RETRIES

        wait = backoff_for(response, attempt)
        warn "  #{response.code} from #{uri.host}, waiting #{wait}s before retry #{attempt + 1}/#{MAX_RETRIES}"
        sleep wait
        get(uri, redirects_left, attempt + 1)
      else
        raise Error, "#{response.code} #{response.message} for #{uri}"
      end
    end

    # Honour Retry-After when it is sent, otherwise back off exponentially.
    def backoff_for(response, attempt)
      retry_after = response["retry-after"].to_i

      return retry_after.clamp(1, MAX_BACKOFF) if retry_after.positive?

      (BASE_BACKOFF**(attempt + 1)).clamp(1, MAX_BACKOFF)
    end

    def request_for(uri)
      Net::HTTP::Get.new(uri).tap do |request|
        request["User-Agent"] = BreedImages.user_agent
        request["Accept"] = BreedImage::CONTENT_TYPES.join(", ")
      end
    end
  end
end
