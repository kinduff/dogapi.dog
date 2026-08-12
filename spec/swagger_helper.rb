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

BREED_IMAGE_SCHEMA = {
  type: :object,
  description: "A picture of the breed, in every size the API serves. " \
               "The attribution must be shown wherever the image is used.",
  properties: {
    id: {type: :string, format: :uuid},
    url: {type: :string, format: :uri, description: "The original file, as imported"},
    thumb: {type: :string, format: :uri, description: "Square 200x200 WebP crop"},
    medium: {type: :string, format: :uri, description: "WebP, longest side 600px"},
    large: {type: :string, format: :uri, description: "WebP, longest side 1200px"},
    attribution: {
      type: :object,
      properties: {
        author: {type: :string, example: "Magdalena Niemiec"},
        license: {type: :string, example: "CC BY-SA 3.0"},
        license_url: {type: :string, format: :uri},
        source: {type: :string, example: "wikimedia_commons"},
        source_url: {type: :string, format: :uri, description: "Page the image was taken from"}
      }
    }
  }
}.freeze

# Everything below is filled in by a research run rather than typed in by
# hand, so any of it can be empty for a breed the sources are quiet about.
BREED_ORIGIN_SCHEMA = {
  type: :object,
  description: "Where the breed comes from",
  properties: {
    country: {type: :string, example: "Japan"},
    region: {type: :string, example: "Akita Prefecture"},
    era: {type: :string, example: "17th century"}
  }
}.freeze

BREED_COAT_SCHEMA = {
  type: :object,
  properties: {
    type: {type: :string, enum: BreedEnrichments::COAT_TYPES, example: "double"},
    length: {type: :string, enum: BreedEnrichments::COAT_LENGTHS, example: "medium"},
    colors: {type: :array, items: {type: :string}, example: %w[red brindle white]}
  }
}.freeze

BREED_TRAITS_SCHEMA = {
  type: :object,
  description: "Ratings from 1 (lowest) to 5 (highest), relative to dogs in general. Estimates, not measurements.",
  properties: BreedEnrichments::RATINGS.to_h { |name|
    [name, {type: :integer, minimum: 1, maximum: 5, example: 3}]
  }.merge(
    exercise_minutes: {type: :integer, description: "Typical daily exercise for an adult", example: 60},
    temperament: {type: :array, items: {type: :string}, example: %w[loyal dignified courageous]}
  )
}.freeze

BREED_SOURCE_SCHEMA = {
  type: :object,
  description: "A page the researched attributes were taken from",
  properties: {
    url: {type: :string, format: :uri},
    title: {type: :string, example: "Akita Dog Breed Information"}
  }
}.freeze

V2_SCHEMAS = {
  Range: RANGE_SCHEMA,
  PaginationMeta: PAGINATION_META_SCHEMA,
  BreedImage: BREED_IMAGE_SCHEMA,
  BreedOrigin: BREED_ORIGIN_SCHEMA,
  BreedCoat: BREED_COAT_SCHEMA,
  BreedTraits: BREED_TRAITS_SCHEMA,
  BreedSource: BREED_SOURCE_SCHEMA,
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
          hypoallergenic: {type: :boolean, example: false},
          male_height: {
            allOf: [{"$ref": "#/components/schemas/Range"}],
            description: "Male height at the withers, in centimetres"
          },
          female_height: {
            allOf: [{"$ref": "#/components/schemas/Range"}],
            description: "Female height at the withers, in centimetres"
          },
          origin: {"$ref": "#/components/schemas/BreedOrigin"},
          coat: {"$ref": "#/components/schemas/BreedCoat"},
          traits: {"$ref": "#/components/schemas/BreedTraits"},
          other_names: {
            type: :array,
            description: "Names the breed also goes by",
            items: {type: :string},
            example: ["Akita Inu", "Japanese Akita"]
          },
          recognized_by: {
            type: :array,
            description: "Kennel clubs that recognise the breed",
            items: {type: :string, enum: BreedEnrichments::REGISTRIES},
            example: %w[AKC FCI]
          },
          sources: {
            type: :array,
            description: "Where the researched attributes above came from",
            items: {"$ref": "#/components/schemas/BreedSource"}
          },
          images: {
            type: :array,
            description: "Pictures of the breed, empty when none have been imported yet",
            items: {"$ref": "#/components/schemas/BreedImage"}
          }
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
