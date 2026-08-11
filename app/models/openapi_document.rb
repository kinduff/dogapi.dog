# frozen_string_literal: true

# Reads one of the generated OpenAPI documents in `swagger/` and exposes it in
# the shape the docs views need, so the reference can be rendered server side
# instead of by a third party javascript bundle.
class OpenapiDocument
  class NotFound < StandardError; end

  Operation = Struct.new(:verb, :path, :summary, :description, :tag, :parameters, :responses, :anchor)

  Response = Struct.new(:code, :description, :schema, :example)

  Parameter = Struct.new(:name, :in, :required, :type, :description, :constraints)

  Field = Struct.new(:path, :type, :reference, :description, :example)

  VERBS = %w[get post put patch delete].freeze
  MAX_DEPTH = 4

  def self.load(version)
    path = Rails.root.join("swagger", version, "swagger.json")
    raise NotFound, "no OpenAPI document for #{version}" unless path.exist?

    new(JSON.parse(path.read), version)
  end

  attr_reader :version

  def initialize(document, version)
    @document = document
    @version = version
  end

  def title = info["title"]

  def summary = info["description"]

  def info = @document.fetch("info", {})

  def contact_email = info.dig("contact", "email")

  def license = info["license"]

  def terms_of_service = info["termsOfService"]

  def base_url = @document.dig("servers", 0, "url")

  def document_path = "/api-docs/#{version}/swagger.json"

  # Tags in declaration order, followed by any tag only referenced by an
  # operation. Each one carries the operations that belong to it.
  def sections
    declared = @document.fetch("tags", []).map { |tag| [tag["name"], tag["description"]] }
    used = operations.map(&:tag).uniq
    names = (declared.map(&:first) + used).uniq.compact

    names.filter_map do |name|
      ops = operations.select { |operation| operation.tag == name }
      next if ops.empty?

      {name: name, description: declared.to_h[name], operations: ops}
    end
  end

  def operations
    @operations ||= @document.fetch("paths", {}).flat_map do |path, item|
      item.slice(*VERBS).map { |verb, operation| build_operation(verb, path, operation) }
    end
  end

  def models
    @document.dig("components", "schemas")&.keys.to_a.reject { |name| envelope?(name) }
  end

  def model_fields(name)
    fields(schema_for(name))
  end

  # Flattens a schema into rows for a table. Nested objects are walked with a
  # dotted path; a `$ref` stops the walk and links to that model instead.
  def fields(schema, prefix = nil, depth = 0)
    schema = resolve(schema)
    properties = schema["properties"]
    return [] if properties.blank? || depth >= MAX_DEPTH

    properties.flat_map do |name, property|
      path = [prefix, name].compact.join(".")
      reference = reference_for(property)
      row = Field.new(
        path: path,
        type: type_label(property),
        reference: reference,
        description: property["description"],
        example: example_for(property)
      )

      [row] + (reference ? [] : fields(property, path, depth + 1))
    end
  end

  def schema_for(name) = @document.dig("components", "schemas", name) || {}

  def anchor_for_model(name) = "model-#{name.underscore.dasherize}"

  private

  def build_operation(verb, path, operation)
    Operation.new(
      verb: verb.upcase,
      path: path,
      summary: operation["summary"],
      description: operation["description"],
      tag: operation.dig("tags", 0),
      anchor: [verb, path.gsub(/[{}\/]+/, "-")].join.squeeze("-").chomp("-"),
      parameters: operation.fetch("parameters", []).map { |param| build_parameter(param) },
      responses: operation.fetch("responses", {}).map { |code, body| build_response(code, body) }
    )
  end

  def build_parameter(param)
    schema = param.fetch("schema", {})
    constraints = []
    constraints << "min #{schema["minimum"]}" if schema["minimum"]
    constraints << "max #{schema["maximum"]}" if schema["maximum"]
    constraints << "default #{schema["default"]}" if schema.key?("default")

    Parameter.new(
      name: param["name"],
      in: param["in"],
      required: param["required"],
      type: type_label(schema),
      description: param["description"],
      constraints: constraints
    )
  end

  def build_response(code, body)
    content = body.dig("content", "application/json") || {}
    example = content.dig("examples", "example", "value") || content["example"]

    Response.new(
      code: code,
      description: body["description"],
      schema: content["schema"],
      example: example
    )
  end

  def resolve(schema)
    return {} if schema.blank?

    if (ref = schema["$ref"])
      resolve(schema_for(ref.split("/").last))
    elsif (all_of = schema["allOf"])
      all_of.map { |part| resolve(part) }.reduce({}) { |acc, part| acc.deep_merge(part) }
    else
      schema
    end
  end

  # The model a property points at, if any, so the table can link to it rather
  # than inline the whole thing again.
  def reference_for(property)
    ref = property["$ref"] ||
      property.dig("items", "$ref") ||
      property["allOf"]&.dig(0, "$ref")

    name = ref&.split("/")&.last
    name if name && !envelope?(name)
  end

  def type_label(property)
    return "array of #{reference_for(property) || type_label(property["items"].to_h)}" if property["type"] == "array"

    reference = reference_for(property)
    return reference if reference

    [property["type"], property["format"]].compact.join(" ").presence || "object"
  end

  def example_for(property)
    value = property["example"] || resolve(property)["example"]
    return if value.nil?

    value.is_a?(String) ? value : value.to_json
  end

  # Collection/resource wrappers exist to describe the JSON:API envelope; they
  # are documented inline with each endpoint, not as models of their own.
  def envelope?(name) = name.end_with?("Collection", "Resource")
end
