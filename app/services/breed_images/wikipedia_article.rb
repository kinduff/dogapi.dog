# frozen_string_literal: true

module BreedImages
  # Every picture a breed's Wikipedia article uses, not just the one it leads
  # with.
  #
  # An article about a breed carries a handful of photographs chosen to show
  # it: the standing portrait, the head, the coat varieties, the dog working.
  # All of them were picked by somebody writing about the breed, which beats
  # any search, and there are enough of them to fill a gallery rather than a
  # single slot.
  #
  # The other language Wikipedias illustrate the same breed with different
  # photographs, and they are reached through the English article's own
  # language links rather than by guessing: the German article about the
  # Bavarian Mountain Scent Hound is called Bayerischer Gebirgsschweißhund,
  # and nothing about our name would have found it.
  class WikipediaArticle < Mediawiki
    include WikipediaTitles

    COMMONS_ENDPOINT = "https://commons.wikimedia.org/w/api.php"

    # The files come from Commons whichever Wikipedia used them, so they share
    # a source with everything else imported from there.
    SOURCE = "wikimedia_commons"

    # The Wikipedias worth asking after the English one. Large, and likely to
    # have written at length about a breed that came from where they are.
    LANGUAGES = %w[de fr es it ja nl pl ru].freeze

    # Files an article uses that are not photographs of the breed: flags beside
    # the country of origin, the featured article star, the sound of a bark.
    REJECTED_FILES = /\b(commons-logo|wiki|edit|star|symbol|ambox|question|
                        disambig|flag[ _]of|icon|\.svg|\.ogg|\.oga|\.webm|\.gif)/xi

    # How many files to ask an article for, and how many titles Commons will
    # describe in one request.
    FILES_PER_ARTICLE = 25
    IMAGE_INFO_BATCH = 25

    def each_candidate
      article = english_article
      return if article.nil?

      seen = Set.new

      files_by_article(article).each do |files|
        fresh = files.reject { |title| !seen.add?(title) }

        fresh.each_slice(IMAGE_INFO_BATCH) do |batch|
          candidates_for(batch).each { |candidate| yield candidate }
        end
      end
    end

    private

    # The English article is the way in: it holds the first set of files and
    # the links to every other language's version of itself.
    def english_article
      article_titles.lazy.filter_map { |title| article_for(title) }.first
    end

    def article_for(title)
      body = get_json(api_uri(
        ENDPOINT,
        titles: title,
        prop: "images|langlinks",
        imlimit: FILES_PER_ARTICLE,
        lllimit: 500,
        redirects: 1
      ))
      page = pages_from(body).first
      return if page.nil? || page.key?("missing")

      files = usable_files(page)
      return if files.empty?

      {files: files, langlinks: langlinks_from(page)}
    end

    # The English article's files first, then each translation's, one language
    # at a time so a caller that only needs a couple never asks for the rest.
    def files_by_article(article)
      to_enum(:each_article_files, article)
    end

    def each_article_files(article)
      yield article[:files]

      LANGUAGES.each do |language|
        title = article[:langlinks][language]
        next if title.blank?

        files = translated_files(language, title)
        yield files if files.any?
      end
    end

    def translated_files(language, title)
      body = get_json(api_uri(
        "https://#{language}.wikipedia.org/w/api.php",
        titles: title,
        prop: "images",
        imlimit: FILES_PER_ARTICLE,
        redirects: 1
      ))
      page = pages_from(body).first
      return [] if page.nil? || page.key?("missing")

      usable_files(page)
    rescue Downloader::Error => e
      # One Wikipedia being unreachable is not a reason to give up on the rest.
      Rails.logger.warn("#{@breed.name}: #{language}.wikipedia: #{e.message}")
      []
    end

    def usable_files(page)
      page["images"].to_a
        .filter_map { |image| image["title"] }
        .reject { |file| file.match?(REJECTED_FILES) }
    end

    # formatversion 1 puts the linked title in a bare `*` key.
    def langlinks_from(page)
      page["langlinks"].to_a.to_h { |link| [link["lang"], link["*"]] }
    end

    # Commons describes a whole batch of titles in one request, so an article's
    # worth of files costs one round trip rather than one each.
    def candidates_for(files)
      body = get_json(api_uri(
        COMMONS_ENDPOINT,
        titles: files.join("|"),
        prop: "imageinfo",
        iiprop: IMAGE_INFO_PROPS
      ))
      pages = pages_from(body).index_by { |page| page["title"] }

      # Kept in the order the article used them: the first picture in an
      # article is usually the best one in it.
      files.filter_map do |file|
        page = pages[file]
        candidate_from(page) if page && !page.key?("missing")
      end
    end
  end
end
