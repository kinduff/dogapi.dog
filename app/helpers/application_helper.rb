# frozen_string_literal: true

module ApplicationHelper
  DEFAULT_DESCRIPTION = "The Dog API provides a wealth of information on dog breeds, groups, and fun facts. " \
                        "Access and integrate this data into your website or application with our easy-to-use JSON API."

  # Descriptions long enough to say something and short enough to survive a
  # search result, which cuts somewhere around 160 characters.
  MAX_DESCRIPTION = 160

  def page_title(separator = " - ")
    [content_for(:title), "Dog API by kinduff"].compact.join(separator)
  end

  def page_heading(title)
    content_for(:title) { title }
    content_tag(:h1, title)
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

  # Structured data for search engines. Rendered with the request nonce, since
  # the policy only lets nonced scripts through.
  def structured_data(payload)
    # A description holding "</script>" would otherwise end the block early, so
    # the characters that could do it are written as escapes instead.
    json = JSON.pretty_generate(payload)
      .gsub("<", "\\u003c")
      .gsub(">", "\\u003e")
      .gsub("&", "\\u0026")

    content_for :structured_data do
      tag.script(
        raw(json), # rubocop:disable Rails/OutputSafety
        type: "application/ld+json",
        nonce: content_security_policy_nonce
      )
    end
  end
end
