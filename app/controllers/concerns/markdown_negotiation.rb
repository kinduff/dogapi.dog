# frozen_string_literal: true

# Answers `Accept: text/markdown` with the page as markdown, so an agent gets
# the text without the layout around it. HTML stays what everyone else gets.
#
# The page is rendered as HTML either way and converted on the way out, which
# is why this is a pair of callbacks and not a template per page.
module MarkdownNegotiation
  extend ActiveSupport::Concern

  MARKDOWN = "text/markdown"
  HTML = "text/html"

  included do
    before_action :negotiate_markdown
    after_action :respond_in_markdown, if: :markdown_wanted?
  end

  private

  def markdown_wanted?
    @markdown_wanted
  end

  # A path that names its own format (/llms.txt, /sitemap.xml) has already
  # chosen, and is left alone.
  def negotiate_markdown
    return if params[:format].present?

    # The same address now has two answers, and a cache has to know which
    # header picks between them.
    response.headers["Vary"] = [response.headers["Vary"], "Accept"].compact_blank.join(", ")

    @markdown_wanted = prefers_markdown?
    # Rails would look for a markdown template and, finding none, refuse.
    request.format = :html if @markdown_wanted
  end

  # Markdown has to be asked for by name and ranked above HTML. A browser
  # never names it, and `*/*` alone is not asking.
  def prefers_markdown?
    accepted = accepted_types
    markdown = accepted.index(MARKDOWN)
    return false if markdown.nil?

    html = accepted.index(HTML)
    html.nil? || markdown < html
  end

  # Media types from the Accept header, most wanted first. Ties keep the order
  # they were written in.
  def accepted_types
    request.headers["Accept"].to_s.split(",").each_with_index.filter_map { |entry, position|
      type, *parameters = entry.split(";").map(&:strip)
      next if type.blank?

      quality = parameters.filter_map { |parameter| parameter[/\Aq=(.+)\z/i, 1] }.first
      quality = quality ? quality.to_f : 1.0
      next if quality.zero?

      [type.downcase, -quality, position]
    }.sort_by { |_, quality, position| [quality, position] }.map(&:first)
  end

  def respond_in_markdown
    return unless response.media_type == HTML && response.body.present?

    page = MarkdownPage.new(response.body, url: request.original_url)

    response.body = page.to_s
    response.content_type = "#{MARKDOWN}; charset=utf-8"
    response.headers["X-Markdown-Tokens"] = page.tokens.to_s
    drop_preload_links
  end

  # Preload hints are for a stylesheet and a script this answer never uses.
  # Any other link, such as where the API is described, still holds.
  def drop_preload_links
    links = response.headers["Link"].to_s.split(/,\s*(?=<)/).reject { |link| link.match?(/rel="?preload/) }

    if links.any?
      response.headers["Link"] = links.join(", ")
    else
      response.headers.delete("Link")
    end
  end
end
