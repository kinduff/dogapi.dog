# frozen_string_literal: true

# A rendered page as markdown, for a model reading it rather than a browser
# drawing it: the title, description and address up top, then whatever sat in
# <main>. Built from the HTML the views already produce, so no page has to be
# written twice and none can drift from what a person sees.
class MarkdownPage
  # What a reader of text cannot use: things that only run, only draw, or only
  # work with a pointer on them.
  NOISE = "script, style, template, svg, form, button, dialog, [hidden], [aria-hidden='true']"

  # A common rule of thumb for English text, close enough to budget with.
  CHARACTERS_PER_TOKEN = 4

  def initialize(html, url:)
    @document = Nokogiri::HTML5(html)
    @url = url
  end

  def to_s
    @to_s ||= "#{front_matter}\n#{body}\n"
  end

  def tokens
    (to_s.length / CHARACTERS_PER_TOKEN.to_f).ceil
  end

  private

  def front_matter
    fields = {
      "title" => @document.at_css("title")&.text,
      "description" => @document.at_css("meta[name='description']")&.[]("content"),
      "url" => @document.at_css("link[rel='canonical']")&.[]("href") || @url
    }

    lines = fields.filter_map do |name, value|
      "#{name}: #{value.squish.to_json}" if value.present?
    end

    ["---", *lines, "---", ""].join("\n")
  end

  def body
    main = @document.at_css("main") || @document.at_css("body")
    return "" if main.nil?

    simplify(main)
    absolutize(main)

    ReverseMarkdown.convert(main.inner_html, unknown_tags: :bypass, github_flavored: true).strip
  end

  # Markup that is fine on a screen and comes out of a markdown converter as
  # run-together text, rewritten into something it has a syntax for.
  def simplify(main)
    # A labelled icon is standing in for a word, so the word replaces it
    # before the rest of the drawings go.
    main.css("svg[aria-label]").each { |icon| icon.replace(@document.create_text_node("#{icon["aria-label"]} ")) }
    main.css(NOISE).remove

    main.css("dl").each { |list| list.replace(definitions(list)) }
    # Folded sections are open to a reader of text: the label becomes a bold
    # line and what it hid follows.
    main.css("summary").each do |summary|
      summary.replace("<p><strong>#{ERB::Util.html_escape(summary.text.squish)}</strong></p>")
    end
    main.css("details").each { |details| details.replace(details.children) }
    # A card is a link around a picture and a few labels. A link holds one
    # line of text in markdown, so the labels become that line.
    main.css("a:has(div, img)").each do |link|
      labels = link.xpath(".//text()").map { |text| text.text.squish }.compact_blank
      link.content = labels.join(", ") if labels.any?
    end
  end

  # Term and definition, one pair to a bullet.
  def definitions(list)
    items = list.css("> dt").map do |term|
      definition = term.next_element
      definition = nil unless definition&.name == "dd"

      "<li><strong>#{term.inner_html.strip}</strong>: #{definition&.inner_html&.strip}</li>"
    end

    "<ul>#{items.join}</ul>"
  end

  # The markdown leaves the site, so a link that only resolves against the page
  # it came from would point nowhere.
  def absolutize(node)
    {"a" => "href", "img" => "src"}.each do |tag, attribute|
      node.css("#{tag}[#{attribute}]").each do |element|
        element[attribute] = URI.join(@url, element[attribute]).to_s
      rescue URI::Error
        next
      end
    end
  end
end
