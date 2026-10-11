# frozen_string_literal: true

# A remote Model Context Protocol server, so AI assistants and agents can use
# the Dog API as a set of tools. Streamable HTTP transport, stateless: every
# POST carries one JSON-RPC message (or a batch) and gets its answer in the
# body. There is no session and no server-initiated stream, so GET and DELETE
# are refused.
class McpController < ActionController::API
  include UmamiTrackable

  PROTOCOL_VERSIONS = %w[2025-06-18 2025-03-26].freeze
  SERVER_VERSION = "1.0.0"
  # Rate limiting counts requests, so a batch is capped or one request could
  # carry as many tool calls as it liked.
  MAX_BATCH = 10

  INSTRUCTIONS = <<~TEXT.squish
    Dog API (dogapi.dog) is free dog data: breeds with descriptions, life span,
    weights and whether they are hypoallergenic, breed groups, dog facts and
    licensed dog pictures. Use search_breeds or list_groups to find a breed,
    get_breed for its details, random_dog_image for a picture (credit the
    attribution it returns) and random_dog_facts for trivia. Link users to the
    breed page URLs the tools return.
  TEXT

  # The body is parsed here, so a malformed one can be answered with a
  # JSON-RPC parse error rather than a Rails 400.
  wrap_parameters false

  before_action :set_active_storage_url_options

  def handle
    return method_not_allowed unless request.post?

    payload = parse_body
    return render_json(error_response(nil, -32700, "Parse error")) if payload == :invalid

    if payload.is_a?(Array)
      return render_json(error_response(nil, -32600, "Invalid Request: empty batch")) if payload.empty?
      return render_json(error_response(nil, -32600, "Invalid Request: batch over #{MAX_BATCH}")) if payload.size > MAX_BATCH

      responses = payload.filter_map { |message| handle_message(message) }
      responses.empty? ? head(:accepted) : render_json(responses)
    else
      response_body = handle_message(payload)
      response_body ? render_json(response_body) : head(:accepted)
    end
  end

  private

  def method_not_allowed
    response.headers["Allow"] = "POST"
    render_json(error_response(nil, -32000, "Method not allowed: this server is stateless and only accepts POST"), status: :method_not_allowed)
  end

  def parse_body
    JSON.parse(request.raw_post.to_s)
  rescue JSON::ParserError
    :invalid
  end

  # Returns the response object, or nil for a notification or a response sent
  # by the client, neither of which gets an answer.
  def handle_message(message)
    return error_response(nil, -32600, "Invalid Request") unless message.is_a?(Hash) && message["jsonrpc"] == "2.0"

    id = message["id"]
    method = message["method"]
    return if method.nil? # a response from the client
    return error_response(id, -32600, "Invalid Request") unless method.is_a?(String)
    return unless message.key?("id") # a notification

    result =
      case method
      when "initialize" then initialize_result(message["params"])
      when "ping" then {}
      when "tools/list" then {tools: Mcp::Tools::DEFINITIONS}
      when "tools/call" then call_tool(message["params"] || {})
      else return error_response(id, -32601, "Method not found: #{method}")
      end

    {jsonrpc: "2.0", id: id, result: result}
  rescue ArgumentError => e
    error_response(id, -32602, "Invalid params: #{e.message}")
  end

  def initialize_result(params)
    requested = params.is_a?(Hash) ? params["protocolVersion"] : nil

    {
      protocolVersion: PROTOCOL_VERSIONS.include?(requested) ? requested : PROTOCOL_VERSIONS.first,
      capabilities: {tools: {listChanged: false}},
      serverInfo: {name: "dogapi.dog", title: "Dog API", version: SERVER_VERSION},
      instructions: INSTRUCTIONS
    }
  end

  def call_tool(params)
    name = params["name"]
    raise ArgumentError, "unknown tool #{name.inspect}" unless Mcp::Tools::NAMES.include?(name)

    (@tool_calls ||= []) << name
    data = Mcp::Tools.new(base_url: request.base_url).call(name, params["arguments"])
    {content: [{type: "text", text: JSON.generate(data)}], structuredContent: data, isError: false}
  rescue Mcp::Tools::Error => e
    {content: [{type: "text", text: e.message}], isError: true}
  rescue ArgumentError
    raise # an unknown tool is a protocol error, answered as -32602
  rescue => e
    Rails.logger.error("MCP tool #{name} failed: #{e.class}: #{e.message}")
    {content: [{type: "text", text: "The tool failed unexpectedly. Try again later."}], isError: true}
  end

  def error_response(id, code, message)
    {jsonrpc: "2.0", id: id, error: {code: code, message: message}}
  end

  def render_json(body, status: :ok)
    render json: body, status: status, content_type: "application/json"
  end

  # Only tool calls are worth counting; handshakes and listings are noise.
  # Each one is tracked as its own endpoint, `mcp:<tool>`.
  def track_api_request
    Array(@tool_calls).each do |tool|
      @tracked_tool = tool
      super
    end
  end

  def event_payload
    super.tap { |payload| payload[:data][:endpoint] = "mcp:#{@tracked_tool}" }
  end

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = {protocol: request.protocol, host: request.host, port: request.optional_port}
  end
end
