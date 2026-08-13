# frozen_string_literal: true

module BreedImages
  # Walks the Commons category a breed has, rather than searching for its name.
  #
  # A file lands in `Category:Akita Inu` because somebody put it there having
  # looked at it, which is a far better signal than a page happening to contain
  # the word Akita. The categories are also where Commons keeps its own quality
  # assessments, so a file that is both in the breed's category and in
  # `Category:Quality images of dogs` has been judged twice by people.
  #
  # Categories are named unpredictably, so several spellings are tried before
  # giving up, and each category's immediate subcategories are walked too.
  class CommonsCategory < Mediawiki
    ENDPOINT = "https://commons.wikimedia.org/w/api.php"
    SOURCE = "wikimedia_commons"

    PAGE_SIZE = 50

    # How many pages of files to walk in one category before moving on. A
    # breed's category rarely holds more than a couple of hundred files, and
    # the ones past that are the overflow nobody sorted.
    MAX_PAGES = 3

    # Commons keeps its categories in namespace 14.
    CATEGORY_NAMESPACE = 14

    # How many categories a search may offer. Past the first couple they are
    # about places, kennels and dog shows rather than the breed.
    SEARCH_RESULTS = 2

    # How many subcategories of a breed's category to descend into. Deeper
    # levels drift off the breed ("Dogs by country", "Dog shows in Poland").
    MAX_SUBCATEGORIES = 10

    # Commons' own review processes. A file in one of these has been judged a
    # good photograph by somebody other than its author, so it goes first.
    ASSESSED_CATEGORIES = [
      "Category:Featured pictures of dogs",
      "Category:Quality images of dogs",
      "Category:Valued images of dogs"
    ].freeze

    def each_candidate
      seen = Set.new

      categories.each do |category|
        members(category).each do |page|
          next unless seen.add?(page["title"])

          candidate = candidate_from(page)
          yield candidate if candidate
        end
      end
    end

    private

    # The breed's own category first, then whatever subcategories it has. A
    # breed with no category at all yields nothing, which is the honest answer:
    # the search adapter is the fallback for those.
    def categories
      to_enum(:each_category)
    end

    def each_category
      roots = candidate_titles.select { |title| category_exists?(title) }
      roots |= searched_titles

      roots.each { |title| yield title }
      roots.each do |title|
        subcategories(title).first(MAX_SUBCATEGORIES).each { |subcategory| yield subcategory }
      end
    end

    # Commons names a breed's category after the breed, but not always the way
    # we spell it: "Category:Akita Inu" for our "Akita", "Category:Dogs of
    # Bavaria" for nothing at all. Trying a handful is cheaper than maintaining
    # a mapping by hand.
    def candidate_titles
      names = [@breed.name, *Array(@breed.other_names)].compact_blank.uniq

      names.flat_map do |name|
        ["Category:#{name}", "Category:#{name} dogs", "Category:#{name.pluralize}"]
      end.uniq
    end

    # Guessing at spellings only goes so far: a breed named after a place
    # shares its category with the place ("Category:Akita" is a city in Japan),
    # and plenty of breeds are filed under a name we do not hold. Asking
    # Commons which of its categories is about this dog finds those.
    def searched_titles
      body = get_json(api_uri(
        ENDPOINT,
        list: "search",
        srsearch: "#{@breed.name} dog",
        srnamespace: CATEGORY_NAMESPACE,
        srlimit: SEARCH_RESULTS
      ))

      # Taken as Commons ranked them, without checking that the name matches:
      # a breed's category is often filed under its name at home, so the
      # Bavarian Mountain Scent Hound lives in
      # `Category:Bayerischer Gebirgsschweißhund` and a name check would throw
      # away the only category there is. The few results a wrong category
      # contributes are what the review pass is for.
      body.dig("query", "search").to_a.filter_map { |page| page["title"] }
    end

    def category_exists?(title)
      body = get_json(api_uri(ENDPOINT, titles: title, prop: "categoryinfo"))
      page = pages_from(body).first

      page.present? && !page.key?("missing")
    end

    def subcategories(title)
      body = get_json(api_uri(
        ENDPOINT,
        list: "categorymembers",
        cmtitle: title,
        cmtype: "subcat",
        cmlimit: MAX_SUBCATEGORIES
      ))

      titles = body.dig("query", "categorymembers").to_a.filter_map { |member| member["title"] }

      # A breed's subcategories include its skeletons and its coats of arms.
      # The same names that disqualify a file disqualify a category of them.
      titles.reject { |title| title.match?(REJECTED_TITLES) }
    end

    # Files in the category, a page at a time, with the assessed ones first
    # within each page: `categories` is asked for alongside the imageinfo so
    # the sort costs no extra request.
    #
    # Sorting within the page rather than across the whole category is the
    # point of pagination here: a caller that stops after ten never pays for
    # the second page, and one that wants fifty still gets them.
    def members(title)
      to_enum(:each_member, title)
    end

    def each_member(title)
      continuation = nil

      MAX_PAGES.times do
        body = get_json(members_uri(title, continuation))
        pages = pages_from(body).sort_by { |page| assessed?(page) ? 0 : 1 }

        pages.each { |page| yield page }

        continuation = body["continue"]
        break if continuation.blank?
      end
    end

    def members_uri(title, continuation = nil)
      params = {
        generator: "categorymembers",
        gcmtitle: title,
        gcmtype: "file",
        gcmlimit: PAGE_SIZE,
        prop: "imageinfo|categories",
        iiprop: IMAGE_INFO_PROPS,
        clcategories: ASSESSED_CATEGORIES.join("|")
      }
      params.merge!(continuation.symbolize_keys) if continuation.present?

      api_uri(ENDPOINT, params)
    end

    # `clcategories` filters the categories reported to the ones asked about,
    # so any category left on the page is one of the assessments.
    def assessed?(page)
      page["categories"].present?
    end
  end
end
