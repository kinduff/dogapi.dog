# frozen_string_literal: true

module Mcp
  # The tools the MCP server offers. Every one is read-only and answers from
  # the same records the v2 API serves, shaped for a model to read rather than
  # in JSON:API: flat, with the page and picture URLs written out.
  class Tools
    class Error < StandardError; end

    READ_ONLY = {readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false}.freeze
    RANDOM = READ_ONLY.merge(idempotentHint: false).freeze
    MAX_PAGE_SIZE = 50
    IMAGE_SIZES = (BreedImage::VARIANTS.keys.map(&:to_s) + ["full"]).freeze

    BREED_ARG = {
      type: "string",
      description: "The breed's id (a UUID), its name (\"Golden Retriever\") or its slug (\"golden-retriever\")."
    }.freeze

    DEFINITIONS = [
      {
        name: "random_dog_facts",
        title: "Random dog facts",
        description: "Returns between 1 and 5 random facts about dogs, each a short sentence. Good for trivia, small talk or a fun fact to end an answer with.",
        inputSchema: {
          type: "object",
          properties: {limit: {type: "integer", minimum: 1, maximum: 5, default: 1, description: "How many facts to return."}},
          additionalProperties: false
        },
        annotations: RANDOM
      },
      {
        name: "search_breeds",
        title: "Search dog breeds",
        description: "Lists dog breeds, optionally only those whose name contains a query (case insensitive). Returns each breed's id, name, group and page URL, plus paging info. Use get_breed for the details of one.",
        inputSchema: {
          type: "object",
          properties: {
            query: {type: "string", description: "Part of a breed name, e.g. \"terrier\". Omit to list every breed."},
            page: {type: "integer", minimum: 1, default: 1},
            page_size: {type: "integer", minimum: 1, maximum: MAX_PAGE_SIZE, default: 20}
          },
          additionalProperties: false
        },
        annotations: READ_ONLY
      },
      {
        name: "get_breed",
        title: "Get a dog breed",
        description: "Everything known about one dog breed: description, life span in years, male and female weight in kg, whether it is hypoallergenic, its group, its page on dogapi.dog and a picture URL with attribution.",
        inputSchema: {type: "object", properties: {breed: BREED_ARG}, required: ["breed"], additionalProperties: false},
        annotations: READ_ONLY
      },
      {
        name: "list_groups",
        title: "List breed groups",
        description: "Lists the breed groups (Herding, Hound, Terrier...) with their id, name, number of breeds and page URL.",
        inputSchema: {type: "object", properties: {}, additionalProperties: false},
        annotations: READ_ONLY
      },
      {
        name: "get_group",
        title: "Get a breed group",
        description: "One breed group and the breeds in it.",
        inputSchema: {
          type: "object",
          properties: {group: {type: "string", description: "The group's id (a UUID), name (\"Hound Group\") or slug (\"hound-group\")."}},
          required: ["group"],
          additionalProperties: false
        },
        annotations: READ_ONLY
      },
      {
        name: "random_dog_image",
        title: "Random dog picture",
        description: "Returns the URL of a dog picture, at random or of a given breed, with the author, licence and source the licence requires you to credit. The URL can be shown directly as an image.",
        inputSchema: {
          type: "object",
          properties: {
            breed: BREED_ARG.merge(description: "Optional. #{BREED_ARG[:description]}"),
            size: {type: "string", enum: IMAGE_SIZES, default: "medium", description: "thumb is 200px square, medium up to 600px, large up to 1200px, full the original."}
          },
          additionalProperties: false
        },
        annotations: RANDOM
      }
    ].freeze

    NAMES = DEFINITIONS.map { |tool| tool[:name] }.freeze

    def initialize(base_url:)
      @base_url = base_url
      @routes = Rails.application.routes.url_helpers
    end

    def call(name, arguments)
      raise Error, "Unknown tool: #{name}" unless NAMES.include?(name)

      send(name, (arguments || {}).to_h.stringify_keys)
    end

    private

    attr_reader :base_url, :routes

    def random_dog_facts(args)
      limit = integer(args["limit"], 1).clamp(1, 5)
      {facts: Fact.random(limit).map(&:body)}
    end

    def search_breeds(args)
      page = [integer(args["page"], 1), 1].max
      page_size = integer(args["page_size"], 20).clamp(1, MAX_PAGE_SIZE)
      scope = Breed.includes(:group).order(:name)
      if (query = args["query"].to_s.strip).present?
        scope = scope.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
      end
      total = scope.count

      {
        breeds: scope.offset((page - 1) * page_size).limit(page_size).map { |breed| breed_summary(breed) },
        page: page,
        page_size: page_size,
        total: total,
        total_pages: (total.to_f / page_size).ceil
      }
    end

    def get_breed(args)
      breed = find_breed!(args["breed"])

      breed_summary(breed).merge(
        description: breed.description,
        life_span_years: range(breed.life_min, breed.life_max),
        male_weight_kg: range(breed.male_weight_min, breed.male_weight_max),
        female_weight_kg: range(breed.female_weight_min, breed.female_weight_max),
        hypoallergenic: breed.hypoallergenic,
        image: image_payload(breed.primary_image, "medium"),
        api_url: "#{base_url}/api/v2/breeds/#{breed.id}"
      )
    end

    def list_groups(_args)
      {groups: Group.includes(:breeds).order(:name).map { |group| group_summary(group).merge(breed_count: group.breeds.size) }}
    end

    def get_group(args)
      group = find_record!(Group, args["group"], "group")
      breeds = group.breeds.includes(:group).order(:name)

      group_summary(group).merge(breeds: breeds.map { |breed| breed_summary(breed).except(:group) })
    end

    def random_dog_image(args)
      size = IMAGE_SIZES.include?(args["size"]) ? args["size"] : "medium"
      image =
        if args["breed"].present?
          find_breed!(args["breed"]).breed_images.with_files.sample
        else
          BreedImage.with_files.offset(rand(BreedImage.count)).first
        end
      raise Error, "No picture available#{" for that breed" if args["breed"].present?}." if image.nil?

      image_payload(image, size).merge(breed: breed_summary(image.breed))
    end

    def breed_summary(breed)
      {
        id: breed.id,
        name: breed.name,
        group: breed.group&.name,
        url: "#{base_url}#{routes.breed_path(slug(breed))}"
      }
    end

    def group_summary(group)
      {id: group.id, name: group.name, url: "#{base_url}#{routes.group_path(slug(group))}"}
    end

    def image_payload(image, size)
      return if image.nil?

      url = image.url_for((size == "full") ? nil : size)
      return if url.blank?

      {image_url: url, attribution: image.attribution}
    end

    def slug(record) = record.name.parameterize.presence || record.id

    def find_breed!(value) = find_record!(Breed, value, "breed")

    # Same lookup the browse pages use: an id, or a slug. A name is accepted
    # too, since it parameterizes to the slug.
    def find_record!(model, value, label)
      value = value.to_s.strip
      raise Error, "Pass a #{label} id, name or slug." if value.empty?

      record =
        if value.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
          model.find_by(id: value)
        else
          model.find_by(id: slugs(model)[value.parameterize])
        end
      record || raise(Error, "No #{label} matches #{value.inspect}. Try search_breeds or list_groups to find one.")
    end

    def slugs(model)
      Rails.cache.fetch("mcp/slugs/#{model.name.underscore}", expires_in: 1.hour) do
        model.pluck(:name, :id).to_h { |name, id| [name.parameterize, id] }
      end
    end

    def range(min, max)
      return if min.nil? && max.nil?

      {min: min, max: max}
    end

    def integer(value, default)
      Integer(value.presence || default)
    rescue ArgumentError, TypeError
      default
    end
  end
end
