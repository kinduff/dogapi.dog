# frozen_string_literal: true

module BreedImages
  # The photograph a breed's Wikipedia article leads with.
  #
  # That one file is the closest thing to a curated answer anywhere: editors
  # argue over it, and what survives is almost always a single adult dog, in
  # focus, filling the frame. One per breed and nothing else, which is exactly
  # what a breed page needs and what a Commons search is worst at finding.
  #
  # Wikipedia only names the file; the licence and the author live on Commons,
  # so the article is asked which picture and Commons is asked about it.
  class WikipediaLead < Mediawiki
    ENDPOINT = "https://en.wikipedia.org/w/api.php"
    COMMONS_ENDPOINT = "https://commons.wikimedia.org/w/api.php"

    # The file ends up in the same place as everything else from Commons, and
    # shares its source id, so a breed never stores it twice.
    SOURCE = "wikimedia_commons"

    # How many articles a search is allowed to offer before giving up on a
    # breed. Past the first few the results are about places and people.
    SEARCH_RESULTS = 3

    def each_candidate
      seen = Set.new

      titles.each do |title|
        file = lead_file_for(title)
        next if file.blank? || !seen.add?(file)

        candidate = candidate_for(file)
        yield candidate if candidate
      end
    end

    private

    # The breed's own name first: a redirect handles the spellings Wikipedia
    # prefers, and alternative names cover the breeds our name does not reach.
    #
    # Plenty of breeds share a name with a place, though — "Akita" is a city
    # in Japan, and its article has no dog in it — so when the plain titles
    # come up empty, Wikipedia is asked which article is about the dog.
    def titles
      to_enum(:each_title)
    end

    def each_title
      names = [@breed.name, *Array(@breed.other_names)].compact_blank.uniq

      names.each { |name| yield name }
      names.each do |name|
        searched_titles(name).each { |title| yield title unless names.include?(title) }
      end
    end

    def searched_titles(name)
      body = get_json(api_uri(
        ENDPOINT,
        list: "search",
        srsearch: "#{name} dog breed",
        srnamespace: 0,
        srlimit: SEARCH_RESULTS
      ))

      titles = body.dig("query", "search").to_a.filter_map { |page| page["title"] }

      # A search for a breed also returns the articles that merely mention it:
      # "Dog", "Dog breed", "List of dog breeds", whose lead images are charts
      # and group portraits. An article about this breed says its name.
      titles.select { |title| title.match?(/#{Regexp.escape(name)}/i) }
    end

    def lead_file_for(title)
      body = get_json(api_uri(ENDPOINT, titles: title, prop: "pageimages", piprop: "name", redirects: 1))
      page = pages_from(body).first
      return if page.nil? || page.key?("missing")

      page["pageimage"].presence
    end

    # `pageimage` is a bare file name; Commons wants the full title.
    def candidate_for(file)
      body = get_json(api_uri(COMMONS_ENDPOINT, titles: "File:#{file}", prop: "imageinfo", iiprop: IMAGE_INFO_PROPS))
      page = pages_from(body).first
      return if page.nil? || page.key?("missing")

      candidate_from(page)
    end
  end
end
