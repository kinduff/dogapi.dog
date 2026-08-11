# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "breeds", swagger_doc: "v2/swagger.json" do
  path "/breeds" do
    get("list breeds") do
      tags "Breeds"
      description <<~TEXT.strip
        Returns every breed, ordered by name and split into pages.

        Pages hold up to 1000 records. A missing, zero, negative or oversized
        `page[size]` falls back to that maximum, so a plain request returns the
        whole collection. Each breed links to the group it belongs to.

        Responses may be cached publicly for up to 5 minutes.
      TEXT
      produces "application/json"

      parameter name: "page[number]", in: :query, required: false,
        schema: {type: :integer, minimum: 1},
        description: "Page number for pagination"
      parameter name: "page[size]", in: :query, required: false,
        schema: {type: :integer, minimum: 1, maximum: 1000},
        description: "Number of records per page (max 1000)"

      response(200, "successful") do
        schema "$ref": "#/components/schemas/BreedCollection"

        example "application/json", :example, {
          data: [
            {
              id: "f9643a80-af1d-422a-9f15-18d466822053",
              type: "breed",
              attributes: {
                name: "Caucasian Shepherd Dog",
                description: "The Caucasian Shepherd dog is a serious guardian breed and should never be taken lightly.",
                hypoallergenic: false,
                life: {min: 15, max: 20},
                male_weight: {min: 50, max: 100},
                female_weight: {min: 50, max: 100}
              },
              relationships: {
                group: {
                  data: {id: "02124eb6-1baa-410c-90ea-6b8629fb0837", type: "group"}
                }
              }
            },
            {
              id: "dc5e84f8-9151-4624-836c-25b4e313118b",
              type: "breed",
              attributes: {
                name: "Bouvier des Flandres",
                description: "They don't build 'em like this anymore.",
                hypoallergenic: false,
                life: {min: 10, max: 14},
                male_weight: {min: 30, max: 40},
                female_weight: {min: 25, max: 35}
              },
              relationships: {
                group: {
                  data: {id: "256db247-70ce-4f08-b6a6-60b27ce369d1", type: "group"}
                }
              }
            }
          ],
          meta: {
            pagination: {current: 1, next: 2, last: 2, records: 340}
          },
          links: {
            self: "https://dogapi.dog/api/v2/breeds",
            current: "https://dogapi.dog/api/v2/breeds?page[number]=1",
            next: "https://dogapi.dog/api/v2/breeds?page[number]=2",
            last: "https://dogapi.dog/api/v2/breeds?page[number]=2"
          }
        }

        run_test!
      end
    end
  end

  path "/breeds/{id}" do
    get("get breed") do
      tags "Breeds"
      description "Returns a single breed. Unknown and malformed ids both return 404."
      produces "application/json"

      parameter name: :id, in: :path, required: true,
        schema: {type: :string, format: :uuid},
        description: "Breed id"

      response(200, "successful") do
        schema "$ref": "#/components/schemas/BreedResource"

        example "application/json", :example, {
          data: {
            id: "f9643a80-af1d-422a-9f15-18d466822053",
            type: "breed",
            attributes: {
              name: "Caucasian Shepherd Dog",
              description: "The Caucasian Shepherd dog is a serious guardian breed and should never be taken lightly.",
              hypoallergenic: false,
              life: {min: 15, max: 20},
              male_weight: {min: 50, max: 100},
              female_weight: {min: 50, max: 100}
            },
            relationships: {
              group: {
                data: {id: "02124eb6-1baa-410c-90ea-6b8629fb0837", type: "group"}
              }
            }
          },
          links: {
            self: "https://dogapi.dog/api/v2/breeds/f9643a80-af1d-422a-9f15-18d466822053"
          }
        }

        let(:id) { create(:breed).id }

        run_test!
      end

      response(404, "no breed with that id") do
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end
