# frozen_string_literal: true

# The MCP server card: a static description of the MCP server at /mcp, so a
# client can learn who it is and where to connect without opening a session.
# Format from SEP-2127, schema kept at
# https://github.com/modelcontextprotocol/experimental-ext-server-card.
#
# It lists no tools on purpose. The specification leaves them to `tools/list`,
# which is the one place they cannot go stale.
class McpServerCardsController < ActionController::API
  SCHEMA = "https://static.modelcontextprotocol.io/schemas/v1/server-card.schema.json"
  MEDIA_TYPE = "application/mcp-server-card+json"
  # Reverse DNS of the domain, then the server's name on it.
  NAME = "dog.dogapi/dogapi"
  # The schema allows a hundred characters.
  DESCRIPTION = "Free dog data: breeds, breed groups, facts and credited pictures. Read-only, no key."
  REPOSITORY = {url: "https://github.com/kinduff/dogapi.dog", source: "github"}.freeze
  # The card only changes with a deploy.
  CACHE_MAX_AGE = 1.hour

  before_action { expires_in CACHE_MAX_AGE, public: true }

  # The card as the specification defines it, at the address it reserves:
  # the server's own URL with /server-card after it.
  def show
    render json: card, content_type: MEDIA_TYPE
  end

  # The same card where discovery tools written against earlier drafts look,
  # with the three fields those drafts named differently. Nothing in them says
  # more than the card or the handshake already does.
  def well_known
    render json: card.merge(
      serverInfo: McpController::SERVER_INFO,
      transport: {type: "streamable-http", endpoint: mcp_url},
      capabilities: McpController::CAPABILITIES
    )
  end

  private

  def card
    {
      "$schema": SCHEMA,
      name: NAME,
      version: McpController::SERVER_VERSION,
      title: McpController::SERVER_INFO[:title],
      description: DESCRIPTION,
      websiteUrl: root_url,
      repository: REPOSITORY,
      remotes: [
        {type: "streamable-http", url: mcp_url, supportedProtocolVersions: McpController::PROTOCOL_VERSIONS}
      ]
    }
  end
end
