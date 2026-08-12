# frozen_string_literal: true

module BreedEnrichments
  # Stands between the model's answer and the database.
  #
  # The schema already guarantees the shape, so everything here is about the
  # values being possible: a 3 metre terrier parses perfectly well. Anything
  # that fails is dropped from the payload and reported, rather than raising —
  # one bad field should not cost a breed the other twenty.
  class Validator
    HEIGHT_CM = (10.0..115.0)
    EXERCISE_MINUTES = (5..300)
    MAX_TEMPERAMENT = 6
    MAX_OTHER_NAMES = 10
    MAX_COLORS = 20
    MAX_PHRASE = 40

    # A dog heavier than this is not a lapdog, and one shorter than this is
    # not a mastiff. Deliberately far apart: the point is to catch a field
    # that belongs to another breed, not to second-guess a breed standard.
    CONTRADICTIONS = [
      {weight_over: 25, height_under: 30},
      {weight_under: 5, height_over: 60}
    ].freeze

    Result = Struct.new(:payload, :rejections, :fatal) do
      def valid? = fatal.nil?

      def rejected?(field) = rejections.any? { |rejection| rejection[:field] == field.to_s }
    end

    def self.call(...) = new(...).call

    def initialize(breed, attributes)
      @breed = breed
      @attributes = attributes
      @payload = {}
      @rejections = []
    end

    def call
      fatal = fatal_problem
      return Result.new({}, @rejections, fatal) if fatal

      @payload["sources"] = sources
      heights
      origin
      coat
      traits
      string_list("other_names", MAX_OTHER_NAMES)
      registries

      Result.new(@payload.compact_blank, @rejections, nil)
    end

    private

    def reject(field, value, reason)
      @rejections << {field: field.to_s, value: value, reason: reason}
      nil
    end

    # Two things make the whole answer worthless rather than partly usable: no
    # source to check it against, and an answer about a different breed.
    def fatal_problem
      answered = @attributes["name"].to_s.strip
      return "researched #{answered.inspect} instead of #{@breed.name.inspect}" unless same_breed?(answered)

      "no usable sources" if sources.empty?
    end

    def same_breed?(answered)
      answered.casecmp?(@breed.name.to_s.strip)
    end

    def sources
      @sources ||= Array(@attributes["sources"]).filter_map do |source|
        url = source.is_a?(Hash) ? source["url"] : nil
        next reject("sources", source, "not an http url") unless url.to_s.match?(%r{\Ahttps?://\S+\z})

        {"url" => url, "title" => source["title"].presence}.compact
      end
    end

    def heights
      %w[male_height female_height].each do |field|
        range = range_for(field, HEIGHT_CM)
        next if range.nil?

        contradiction = contradicted(range)
        next reject(field, range, contradiction) if contradiction

        @payload[field] = range
      end
    end

    def range_for(field, bounds)
      value = @attributes[field]
      return if value.blank?

      min, max = value.values_at("min", "max").map { |number| number&.to_f }
      return reject(field, value, "incomplete range") if min.nil? || max.nil?
      return reject(field, value, "min above max") if min > max
      return reject(field, value, "outside #{bounds}") unless bounds.cover?(min) && bounds.cover?(max)

      {"min" => min.round, "max" => max.round}
    end

    # The weights already stored are the only independent numbers available,
    # so they are what a new height gets checked against.
    def contradicted(height)
      weight_min = @breed.male_weight_min || @breed.female_weight_min
      weight_max = @breed.male_weight_max || @breed.female_weight_max
      return if weight_min.nil? || weight_max.nil?

      rule = CONTRADICTIONS.find do |bounds|
        (bounds[:weight_over] && weight_min.to_f > bounds[:weight_over] && height["max"] < bounds[:height_under]) ||
          (bounds[:weight_under] && weight_max.to_f < bounds[:weight_under] && height["min"] > bounds[:height_over])
      end

      "does not match the stored weight of #{weight_min}-#{weight_max} kg" if rule
    end

    def origin
      value = @attributes["origin"]
      return if value.blank?

      origin = value.slice("country", "region", "era").transform_values { |text| phrase(text) }.compact_blank
      return reject("origin", value, "no country") if origin["country"].blank?

      @payload["origin"] = origin
    end

    def coat
      value = @attributes["coat"]
      return if value.blank?

      coat = {
        "type" => enum_value("coat.type", value["type"], COAT_TYPES),
        "length" => enum_value("coat.length", value["length"], COAT_LENGTHS),
        "colors" => words(Array(value["colors"]).first(MAX_COLORS))
      }.compact_blank

      @payload["coat"] = coat if coat.present?
    end

    def traits
      value = @attributes["traits"]
      return if value.blank?

      traits = RATINGS.to_h { |name| [name.to_s, rating(name, value[name.to_s])] }
      traits["exercise_minutes"] = exercise_minutes(value["exercise_minutes"])
      traits["temperament"] = words(Array(value["temperament"]).first(MAX_TEMPERAMENT))

      @payload["traits"] = traits.compact_blank
    end

    def rating(name, value)
      return if value.nil?
      return reject("traits.#{name}", value, "not a rating from 1 to 5") unless (1..5).cover?(value)

      value
    end

    def exercise_minutes(value)
      return if value.nil?
      return reject("traits.exercise_minutes", value, "outside #{EXERCISE_MINUTES}") unless EXERCISE_MINUTES.cover?(value)

      value
    end

    def registries
      names = Array(@attributes["recognized_by"]).filter_map do |name|
        enum_value("recognized_by", name, REGISTRIES)
      end

      @payload["recognized_by"] = names.uniq
    end

    def string_list(field, limit)
      @payload[field] = words(Array(@attributes[field]).first(limit)).uniq
    end

    def enum_value(field, value, allowed)
      return if value.blank?
      return reject(field, value, "not one of #{allowed.join(", ")}") unless allowed.include?(value)

      value
    end

    def words(values) = values.filter_map { |value| phrase(value) }

    def phrase(value)
      text = value.to_s.strip
      text if text.present? && text.length <= MAX_PHRASE
    end
  end
end
