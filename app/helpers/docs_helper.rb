# frozen_string_literal: true

module DocsHelper
  # The descriptions in the OpenAPI document are plain text with blank lines
  # between paragraphs and `backticks` around code. Everything is escaped first,
  # so the document can never inject markup.
  def api_text(text)
    return if text.blank?

    paragraphs = text.split(/\n{2,}/).map do |paragraph|
      escaped = ERB::Util.html_escape(paragraph.strip)
      with_code = escaped.gsub(/`([^`]+)`/) { "<code>#{$1}</code>" }

      tag.p(with_code.html_safe) # rubocop:disable Rails/OutputSafety
    end

    safe_join(paragraphs)
  end

  LEXERS = {
    "json" => Rouge::Lexers::JSON,
    "shell" => Rouge::Lexers::Shell,
    "javascript" => Rouge::Lexers::Javascript
  }.freeze

  # One span per line so the viewer can number them with a CSS counter, each
  # line highlighted on its own. Lexing per line keeps the markup well formed
  # whatever the content does; the blocks here never carry a token that spans
  # more than one line.
  def api_code_lines(text, language = nil)
    lexer = LEXERS[language.to_s]&.new
    formatter = Rouge::Formatters::HTML.new if lexer

    lines = text.to_s.split("\n", -1).map do |line|
      content = lexer ? formatter.format(lexer.lex(line)).html_safe : line # rubocop:disable Rails/OutputSafety

      tag.span(content, class: "code-line")
    end

    safe_join(lines, "\n")
  end

  def api_json(value)
    JSON.pretty_generate(value)
  end

  # A copy-pasteable request for an operation, with path parameters filled in
  # from the documented example when there is one.
  def api_curl(document, operation)
    path = operation.path.gsub(/\{(\w+)\}/) { api_example_id(operation) || "{#{$1}}" }
    query = operation.parameters.select { |param| param.in == "query" }

    url = "#{document.base_url}#{path}"
    url += "?#{query.first.name}=#{api_example_value(query.first)}" if query.any?

    "curl -s \"#{url}\""
  end

  def api_method_class(verb)
    "api-method api-method-#{verb.downcase}"
  end

  # The path prefix of the documented server, e.g. "/api/v2". Try-it requests
  # use it against the current origin instead of the canonical host.
  def api_base_path(document)
    URI.parse(document.base_url.to_s).path
  rescue URI::InvalidURIError
    ""
  end

  # What a try-it field starts with: the documented example for a path id, the
  # declared default for a query parameter, otherwise blank.
  def api_try_default(_document, operation, parameter)
    return api_example_id(operation) if parameter.in == "path"

    parameter.constraints.find { |constraint| constraint.start_with?("default ") }&.delete_prefix("default ")
  end

  # Where a parameter goes, said plainly.
  def api_parameter_place(parameter)
    case parameter.in
    when "path" then "in the URL"
    when "query" then "after the ?"
    else parameter.in
    end
  end

  # The first response example for an operation, trimmed to a couple of records
  # so the block stays readable next to the explanation.
  def api_short_example(operation, keep: 1)
    example = operation.responses.find { |response| response.code == "200" }&.example
    return if example.blank?

    data = example["data"]
    return example unless data.is_a?(Array) && data.size > keep

    example.merge("data" => data.first(keep))
  end

  private

  def api_example_id(operation)
    example = operation.responses.find { |response| response.code == "200" }&.example
    example&.dig("data", "id")
  end

  def api_example_value(parameter)
    return 1 if parameter.type.to_s.start_with?("integer")

    "value"
  end
end
