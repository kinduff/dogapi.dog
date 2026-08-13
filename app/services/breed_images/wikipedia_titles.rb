# frozen_string_literal: true

module BreedImages
  # Finding the English Wikipedia article about a breed.
  #
  # Harder than it sounds: plenty of breeds share a name with the place they
  # came from, and the place usually won the article. "Akita" is a city in
  # Japan, "Havanese" redirects sensibly, "Bavarian Mountain Scent Hound" is
  # filed under a shorter name. So the breed's own names are tried first, and
  # then Wikipedia is asked which of its articles is about the dog.
  module WikipediaTitles
    ENDPOINT = "https://en.wikipedia.org/w/api.php"

    # How many articles a search may offer before giving up on a breed. Past
    # the first few the results are about places and people.
    SEARCH_RESULTS = 3

    private

    def article_titles
      to_enum(:each_article_title)
    end

    def each_article_title
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
      # "Dog", "Dog breed", "List of dog breeds", whose pictures are charts and
      # group portraits. An article about this breed says most of its name.
      titles.select { |title| about?(title, name) }
    end

    # Half the breed's own words, not all of them: Wikipedia files the
    # Bavarian Mountain Scent Hound under "Bavarian Mountain Hound", and an
    # exact match would throw away the only article there is. Short words are
    # ignored because "of" and "the" say nothing about what an article covers.
    def about?(title, name)
      words = significant_words(name)
      return title.match?(/#{Regexp.escape(name)}/i) if words.empty?

      matched = words.count { |word| title.match?(/#{Regexp.escape(word)}/i) }

      matched >= (words.size / 2.0).ceil
    end

    def significant_words(name) = name.scan(/[[:alnum:]]+/).select { |word| word.length >= 4 }
  end
end
