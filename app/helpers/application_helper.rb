# frozen_string_literal: true

module ApplicationHelper
  DEFAULT_DESCRIPTION = "The Dog API provides a wealth of information on dog breeds, groups, and fun facts. " \
                        "Access and integrate this data into your website or application with our easy-to-use JSON API."

  # Descriptions long enough to say something and short enough to survive a
  # search result, which cuts somewhere around 160 characters.
  MAX_DESCRIPTION = 160

  def page_title(separator = " | ")
    [content_for(:title), "Dog API"].compact.join(separator)
  end

  # The page's own heading, and the title that goes with it. A heading reads
  # inside a page that already says what the site is; a title has to stand on
  # its own in a search result, so it can say more.
  def page_heading(heading, title: heading)
    content_for(:title) { title }
    content_tag(:h1, heading)
  end

  def page_description
    content_for?(:description) ? truncate(content_for(:description).to_s.squish, length: MAX_DESCRIPTION) : DEFAULT_DESCRIPTION
  end

  def page_image
    content_for?(:og_image) ? content_for(:og_image) : image_url("social.jpg")
  end

  # One address per page. A page reachable by more than one URL, such as a
  # breed under both its slug and its API id, says which one counts.
  def canonical_url
    path = content_for?(:canonical_path) ? content_for(:canonical_path).to_s : request.path

    "#{request.base_url}#{path}"
  end

  # A sponsor is only shown when there is both something to name and somewhere
  # to send the click. Anything less falls back to the "for rent" copy.
  def sponsor_present?
    ENV["SPONSOR_NAME"].present? && ENV["SPONSOR_URL"].present?
  end

  # Share of breeds that have at least one picture, as a number between 0 and
  # 100. Zero breeds counts as zero rather than dividing by nothing.
  def image_coverage(stats)
    return 0.0 if stats[:breeds].to_i.zero?

    100.0 * stats[:covered] / stats[:breeds]
  end

  # One line naming everyone the licence says has to be named, for the tooltip
  # on a thumbnail.
  def image_credit(breed_image)
    [breed_image.author.presence || "Unknown author", breed_image.license, breed_image.source_id].compact.join(" · ")
  end

  # Who the site is and how its search works, on every page. The search action
  # is the breed list's own query parameter, so a result can send a visitor
  # straight into it.
  def site_structured_data
    payload = [
      {
        "@context" => "https://schema.org",
        "@type" => "WebSite",
        "name" => "Dog API",
        "alternateName" => "Dog API by kinduff",
        "url" => "#{request.base_url}/",
        "description" => DEFAULT_DESCRIPTION,
        "potentialAction" => {
          "@type" => "SearchAction",
          "target" => {
            "@type" => "EntryPoint",
            "urlTemplate" => "#{request.base_url}/breeds?q={search_term_string}"
          },
          "query-input" => "required name=search_term_string"
        }
      },
      {
        "@context" => "https://schema.org",
        "@type" => "Organization",
        "name" => "Dog API",
        "url" => "#{request.base_url}/",
        "logo" => image_url("social.jpg"),
        "email" => "dev@dogapi.dog",
        "sameAs" => ["https://github.com/kinduff/dogapi.dog"]
      }
    ]

    safe_join(payload.map { |item| structured_data_tag(item) })
  end

  # A trail from the homepage to this page, as search engines show it in place
  # of the bare URL. `crumbs` is a list of [name, path] pairs, the last one
  # being the page itself.
  def breadcrumb_structured_data(crumbs)
    items = [["Home", "/"], *crumbs].each_with_index.map do |(name, path), index|
      {
        "@type" => "ListItem",
        "position" => index + 1,
        "name" => name,
        "item" => "#{request.base_url}#{path}"
      }
    end

    structured_data("@context" => "https://schema.org", "@type" => "BreadcrumbList", "itemListElement" => items)
  end

  # The questions the page already answers in its own words, repeated in the
  # shape a search engine can show them in. `entries` maps a question to the
  # markup of its answer — the same markup the page renders — so the two cannot
  # end up saying different things.
  def faq_structured_data(entries)
    payload = {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => entries.map do |question, answer|
        {
          "@type" => "Question",
          "name" => question,
          "acceptedAnswer" => {"@type" => "Answer", "text" => strip_tags(answer).squish}
        }
      end
    }

    structured_data(payload)
  end

  # Structured data for search engines. Rendered with the request nonce, since
  # the policy only lets nonced scripts through.
  def structured_data(payload)
    content_for :structured_data do
      structured_data_tag(payload)
    end
  end

  private

  def structured_data_tag(payload)
    # A description holding "</script>" would otherwise end the block early, so
    # the characters that could do it are written as escapes instead.
    json = JSON.pretty_generate(payload)
      .gsub("<", "\\u003c")
      .gsub(">", "\\u003e")
      .gsub("&", "\\u0026")

    tag.script(
      raw(json), # rubocop:disable Rails/OutputSafety
      type: "application/ld+json",
      nonce: content_security_policy_nonce
    )
  end
end
