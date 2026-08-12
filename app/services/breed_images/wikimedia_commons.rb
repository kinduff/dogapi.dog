# frozen_string_literal: true

module BreedImages
  # Searches Wikimedia Commons for pictures of a breed.
  #
  # Commons is the only large dog photo collection whose licences allow
  # re-hosting the files on our own bucket, as long as the author and licence
  # travel with the image. Both come back in the `extmetadata` block.
  #
  # Full text search is the widest net Commons offers and the least precise
  # one: it matches anything whose page mentions the words. `CommonsCategory`
  # asks the same site a narrower question and is the better first choice; this
  # stays for the breeds no category covers.
  class WikimediaCommons < Mediawiki
    ENDPOINT = "https://commons.wikimedia.org/w/api.php"
    SOURCE = "wikimedia_commons"

    # How many search results to ask for at a time, and how many pages of them
    # to walk before accepting that Commons has nothing else to offer.
    PAGE_SIZE = 20
    MAX_PAGES = 5

    # Every usable result Commons has, the next page fetched only when the
    # caller asks for more. Most of a search is drawings, diagrams and badly
    # licensed files, so a caller that needs five may have to look at forty.
    #
    # `to_enum` rather than `Enumerator.new`: the latter runs its block in a
    # Fiber, and a constant autoloaded for the first time inside one raises
    # NameError in development.
    def each_candidate
      continuation = nil

      MAX_PAGES.times do
        body = get_json(search_uri(continuation))

        pages_from(body).each do |page|
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

    def search_uri(continuation = nil)
      params = {
        generator: "search",
        gsrsearch: "filetype:bitmap #{@breed.name} dog",
        gsrnamespace: FILE_NAMESPACE,
        gsrlimit: PAGE_SIZE,
        prop: "imageinfo",
        iiprop: IMAGE_INFO_PROPS
      }
      params.merge!(continuation.symbolize_keys) if continuation.present?

      api_uri(ENDPOINT, params)
    end
  end
end
