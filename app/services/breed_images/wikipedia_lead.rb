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
    include WikipediaTitles

    COMMONS_ENDPOINT = "https://commons.wikimedia.org/w/api.php"

    # The file ends up in the same place as everything else from Commons, and
    # shares its source id, so a breed never stores it twice.
    SOURCE = "wikimedia_commons"

    def each_candidate
      seen = Set.new

      article_titles.each do |title|
        file = lead_file_for(title)
        next if file.blank? || !seen.add?(file)

        candidate = candidate_for(file)
        yield candidate if candidate
      end
    end

    private

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
