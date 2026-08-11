# frozen_string_literal: true

require "rails_helper"

RANGE_SCHEMA = {
  type: :object,
  description: "A minimum and maximum, both optional. Empty when unknown.",
  properties: {
    min: {type: :integer, example: 10},
    max: {type: :integer, example: 14}
  }
}.freeze

PAGINATION_META_SCHEMA = {
  type: :object,
  properties: {
    current: {type: :integer, description: "Current page number", example: 1},
    next: {type: :integer, description: "Next page number, absent on the last page", example: 2},
    last: {type: :integer, description: "Last page number", example: 2},
    records: {type: :integer, description: "Total number of records", example: 340}
  }
}.freeze

COLLECTION_LINKS_SCHEMA = {
  type: :object,
  properties: {
    self: {type: :string, format: :uri},
    current: {type: :string, format: :uri},
    next: {type: :string, format: :uri},
    last: {type: :string, format: :uri}
  }
}.freeze

RESOURCE_LINKS_SCHEMA = {
  type: :object,
  properties: {self: {type: :string, format: :uri}}
}.freeze

def relationship_schema(type)
  {
    type: :object,
    properties: {
      data: {
        type: :object,
        properties: {
          id: {type: :string, format: :uuid},
          type: {type: :string, enum: [type]}
        }
      }
    }
  }
end

def relationship_collection_schema(type)
  {
    type: :object,
    properties: {
      data: {
        type: :array,
        items: {
          type: :object,
          properties: {
            id: {type: :string, format: :uuid},
            type: {type: :string, enum: [type]}
          }
        }
      }
    }
  }
end

V2_SCHEMAS = {
  Range: RANGE_SCHEMA,
  PaginationMeta: PAGINATION_META_SCHEMA,
  Breed: {
    type: :object,
    properties: {
      id: {type: :string, format: :uuid},
      type: {type: :string, enum: ["breed"]},
      attributes: {
        type: :object,
        properties: {
          name: {type: :string, example: "Caucasian Shepherd Dog"},
          description: {
            type: :string,
            example: "The Caucasian Shepherd dog is a serious guardian breed and should never be taken lightly."
          },
          life: {allOf: [{"$ref": "#/components/schemas/Range"}], description: "Life expectancy in years"},
          male_weight: {allOf: [{"$ref": "#/components/schemas/Range"}], description: "Male weight in kilograms"},
          female_weight: {allOf: [{"$ref": "#/components/schemas/Range"}], description: "Female weight in kilograms"},
          hypoallergenic: {type: :boolean, example: false}
        }
      },
      relationships: {
        type: :object,
        properties: {group: relationship_schema("group")}
      }
    }
  },
  Group: {
    type: :object,
    properties: {
      id: {type: :string, format: :uuid},
      type: {type: :string, enum: ["group"]},
      attributes: {
        type: :object,
        properties: {name: {type: :string, example: "Herding Group"}}
      },
      relationships: {
        type: :object,
        properties: {breeds: relationship_collection_schema("breed")}
      }
    }
  },
  Fact: {
    type: :object,
    properties: {
      id: {type: :string, format: :uuid},
      type: {type: :string, enum: ["fact"]},
      attributes: {
        type: :object,
        properties: {
          body: {
            type: :string,
            example: "Two Labradors, Lucky and Flo, were the first dogs known for sniffing out pirated DVDs."
          }
        }
      }
    }
  }
}.freeze

def collection_schema(ref, paginated: true)
  properties = {data: {type: :array, items: {"$ref": "#/components/schemas/#{ref}"}}}
  if paginated
    properties[:meta] = {
      type: :object,
      properties: {pagination: {"$ref": "#/components/schemas/PaginationMeta"}}
    }
    properties[:links] = COLLECTION_LINKS_SCHEMA
  end

  {type: :object, properties: properties}
end

def resource_schema(ref)
  {
    type: :object,
    properties: {
      data: {"$ref": "#/components/schemas/#{ref}"},
      links: RESOURCE_LINKS_SCHEMA
    }
  }
end

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s
  config.openapi_format = :json
  config.openapi_specs = {
    "v1/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "API V1",
        version: "1.0.0",
        description: "The Dog Facts API allows users to access a collection of dog facts that have been submitted by members of the public. The API is simple to use and provides a variety of options for retrieving dog facts. With the V1 version of the API, users can access dog facts in a variety of formats, including plain text and HTML.",
        termsOfService: "https://dogapi.dog/terms",
        contact: {
          email: "dev@dogapi.dog"
        },
        license: {
          name: "MIT",
          url: "https://github.com/kinduff/dogapi.dog/blob/master/LICENSE"
        }
      },
      servers: [{url: "https://dogapi.dog/api/v1"}]
    },
    "v2/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "API V2",
        version: "1.0.0",
        description: "The Dog API provides a wealth of information on dog breeds, groups, and fun facts. Access and integrate this data into your website or application with our easy-to-use JSON API.",
        termsOfService: "https://dogapi.dog/terms",
        contact: {
          email: "dev@dogapi.dog"
        },
        license: {
          name: "MIT",
          url: "https://github.com/kinduff/dogapi.dog/blob/master/LICENSE"
        }
      },
      servers: [{url: "https://dogapi.dog/api/v2"}],
      tags: [
        {name: "Breeds", description: "Over 340 dog breeds, each one belonging to a group."},
        {name: "Groups", description: "The breed groups, each one listing the breeds it contains."},
        {name: "Facts", description: "Random dog facts."}
      ],
      components: {
        schemas: V2_SCHEMAS.merge(
          BreedCollection: collection_schema("Breed"),
          BreedResource: resource_schema("Breed"),
          GroupCollection: collection_schema("Group"),
          GroupResource: resource_schema("Group"),
          FactCollection: collection_schema("Fact", paginated: false)
        )
      }
    }
  }
end
