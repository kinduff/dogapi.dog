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

        Most breeds have no picture imported yet.
        `filter[has_images]=true` narrows the collection to the ones that do,
        which is what you want if you are putting photographs on a screen.

        Responses may be cached publicly for up to 5 minutes.
      TEXT
      produces "application/json"

      parameter name: "page[number]", in: :query, required: false,
        schema: {type: :integer, minimum: 1},
        description: "Page number for pagination"
      parameter name: "page[size]", in: :query, required: false,
        schema: {type: :integer, minimum: 1, maximum: 1000},
        description: "Number of records per page (max 1000)"
      parameter name: "filter[has_images]", in: :query, required: false,
        schema: {type: :boolean},
        description: "Only breeds that have at least one picture"

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
                female_weight: {min: 50, max: 100},
                images: []
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
                female_weight: {min: 25, max: 35},
                images: []
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
              female_weight: {min: 50, max: 100},
              images: [
                {
                  id: "6d1e1b0c-0f0b-4b4a-9c4c-8e1f4b7f7f52",
                  url: "https://images.dogapi.dog/caucasian-shepherd-dog.jpg",
                  thumb: "https://images.dogapi.dog/caucasian-shepherd-dog-thumb.webp",
                  medium: "https://images.dogapi.dog/caucasian-shepherd-dog-medium.webp",
                  large: "https://images.dogapi.dog/caucasian-shepherd-dog-large.webp",
                  attribution: {
                    author: "Magdalena Niemiec",
                    license: "CC BY-SA 3.0",
                    license_url: "https://creativecommons.org/licenses/by-sa/3.0/",
                    source: "wikimedia_commons",
                    source_url: "https://commons.wikimedia.org/wiki/File:Caucasian_Shepherd_Dog.jpg"
                  }
                }
              ]
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

  path "/breeds/{id}/image" do
    get("get breed image") do
      tags "Breeds"
      description <<~TEXT.strip
        Redirects to a picture of the breed, so the URL can be used directly in
        an `<img>` tag. Returns 404 when the breed has no images yet.

        Images come from Wikimedia Commons and are served under the licence of
        their author. The credit for each one is in the `images` attribute of
        the breed itself, and it has to be displayed alongside the picture.
      TEXT

      parameter name: :id, in: :path, required: true,
        schema: {type: :string, format: :uuid},
        description: "Breed id"
      parameter name: :size, in: :query, required: false,
        schema: {type: :string, enum: %w[thumb medium large full], default: "medium"},
        description: "Which size to redirect to. `full` is the original file. An unknown size falls back to `medium`."
      parameter name: :random, in: :query, required: false,
        schema: {type: :boolean, default: false},
        description: "Redirect to any of the breed's images instead of the first one"

      response(302, "redirect to the image file") do
        let(:id) { create(:breed_image).breed_id }
        let(:size) { "medium" }
        let(:random) { false }

        run_test!
      end

      response(404, "the breed has no images, or does not exist") do
        let(:id) { create(:breed).id }
        let(:size) { "medium" }
        let(:random) { false }

        run_test!
      end
    end
  end

  path "/breeds/image" do
    get("get a random breed image") do
      tags "Breeds"
      description <<~TEXT.strip
        Redirects to a picture of a randomly chosen breed. Returns 404 while no
        images have been imported.
      TEXT

      parameter name: :size, in: :query, required: false,
        schema: {type: :string, enum: %w[thumb medium large full], default: "medium"},
        description: "Which size to redirect to. `full` is the original file."

      response(302, "redirect to the image file") do
        before { create(:breed_image) }

        let(:size) { "medium" }

        run_test!
      end

      response(404, "no images have been imported") do
        let(:size) { "medium" }

        run_test!
      end
    end
  end
end
