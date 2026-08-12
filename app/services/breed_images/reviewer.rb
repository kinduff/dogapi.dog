# frozen_string_literal: true

require "anthropic"
require "base64"

module BreedImages
  # Looks at a stored picture and says how good it is as the one photograph a
  # breed page leads with.
  #
  # Every filter before this one judges a file by its metadata: how big it is,
  # what its title says, which licence it carries. None of that can tell a
  # portrait of one dog from three dogs at a show, a blurred phone snap, or a
  # picture whose subject is the sofa. This can, because it looks at the pixels.
  #
  # The medium variant is what gets sent: 600px is more than enough to judge
  # composition and focus, and a tenth of the bytes of the original.
  class Reviewer
    MAX_TOKENS = 1_000

    # A picture only needs judging once. Deep reasoning does not make a better
    # answer here, and there are thousands of pictures.
    EFFORT = :low

    VARIANT = :medium

    # What the score means, so a threshold in a rake task and a note in the
    # database refer to the same scale.
    GOOD_ENOUGH = 6

    Result = Struct.new(:score, :notes, :attributes, :usage) do
      def good_enough? = score.to_i >= GOOD_ENOUGH

      def rejected? = !good_enough?

      # Not a picture of this breed at all: no dog in it, or several pictures
      # arranged into one. Scored 0 whatever the model said, so a run over
      # every breed leaves one number that means "wrong picture" rather than
      # "poor picture", and a cleanup can act on it.
      def unusable? = attributes["shows_a_dog"] == false || attributes["is_collage"] == true
    end

    SYSTEM = <<~PROMPT
      You are judging photographs for a dog breed encyclopedia. Each page shows
      one picture at the top, and it has to show the reader what the breed looks
      like at a glance.

      Score from 0 to 10, where 10 is a photograph you would put on the cover.

      What a high score needs:
      - exactly one dog, unmistakably the subject of the photograph
      - the whole dog visible, or at least a clear head and shoulders portrait
      - sharp, well exposed, and taken in daylight or good light
      - the dog filling a good part of the frame, seen from the side or the
        front rather than from above or behind
      - a plain or uncluttered background

      What pulls a score down, in rough order of how much:
      - several dogs, or a dog that is hard to pick out of the picture
      - people, hands, leads and crowds; show rings and agility equipment
      - blur, heavy shadow, night shots, and heavy filters or vignettes
      - watermarks, captions, logos, borders and collage frames
      - anything that is not a photograph of a live dog: drawings, paintings,
        statues, toys, taxidermy, or a dog in costume
      - puppies, when the breed's adult appearance is what a reader is after

      Two cases score 0 outright, and `shows_a_dog` is false for both:

      - there is no dog in the picture at all: a kennel, a bowl, a lead, a
        landscape, a person on their own, a page of text
      - the picture is not one photograph but several arranged together: a
        grid, a collage, a montage, a before and after, a size comparison
        chart. These are common as article lead images and are the worst
        possible choice for a page that shows one picture.

      Judge only what you can see. You are not being asked to verify the breed
      against a standard: say whether the animal is plausibly the breed named,
      and score it as a photograph.

      Keep `notes` to one short sentence explaining the score.
    PROMPT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[score shows_a_dog single_dog whole_dog_visible sharp plausible_breed
        has_people has_text_or_watermark is_photograph is_collage is_puppy notes],
      properties: {
        # Spelled out rather than bounded: structured outputs refuse numeric
        # and string constraints, so the range has to be the type itself.
        score: {type: "integer", enum: (0..10).to_a},
        # Asked separately from the score because a picture with no dog in it
        # is not a bad picture of the breed, it is the wrong picture, and a
        # caller cleaning up wants to tell those apart.
        shows_a_dog: {type: "boolean"},
        single_dog: {type: "boolean"},
        whole_dog_visible: {type: "boolean"},
        sharp: {type: "boolean"},
        plausible_breed: {type: "boolean"},
        has_people: {type: "boolean"},
        has_text_or_watermark: {type: "boolean"},
        is_photograph: {type: "boolean"},
        is_collage: {type: "boolean"},
        is_puppy: {type: "boolean"},
        notes: {type: "string"}
      }
    }.freeze

    def self.call(...) = new(...).call

    def initialize(breed_image, model: BreedImages.review_model, client: BreedImages.review_client)
      @breed_image = breed_image
      @model = model
      @client = client
    end

    def call
      data, content_type = image_data

      response = request(data, content_type)
      attributes = parse(response)

      result = Result.new(
        score: attributes["score"],
        notes: attributes["notes"],
        attributes: attributes,
        usage: response.usage.to_h
      )
      result.score = 0 if result.unusable?
      result
    rescue Anthropic::Errors::Error => e
      raise Error, "#{@model}: #{e.message}"
    end

    private

    def image_data
      raise Error, "#{@breed_image.id}: no file attached" unless @breed_image.file.attached?

      variant = @breed_image.file.variant(VARIANT).processed

      [Base64.strict_encode64(variant.download), "image/webp"]
    end

    def request(data, content_type)
      @client.messages.create(
        model: @model,
        max_tokens: MAX_TOKENS,
        # The rubric is identical for every picture in a run, so the cache
        # covers everything up to the image itself.
        system_: [{type: "text", text: SYSTEM, cache_control: {type: "ephemeral"}}],
        output_config: {effort: EFFORT, format_: {type: :json_schema, schema: SCHEMA}},
        messages: [{
          role: "user",
          content: [
            {type: "image", source: {type: "base64", media_type: content_type, data: data}},
            {type: "text", text: "This is offered as a picture of the #{breed_name}. Score it."}
          ]
        }]
      )
    end

    def breed_name = @breed_image.breed.name

    def parse(response)
      raise Error, "#{label}: refused (#{response.stop_details&.category})" if response.stop_reason == :refusal

      text = response.content.select { |block| block.type == :text }.map(&:text).join.strip
      raise Error, "#{label}: no text in response (#{response.stop_reason})" if text.empty?

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise Error, "#{label}: #{e.message}"
    end

    def label = "#{breed_name} (#{@breed_image.source_id})"
  end
end
