# frozen_string_literal: true

# Copy for a single breed page, written strictly from the columns we hold:
# nothing here states a fact that is not in the record.
module BreedPageHelper
  # Answers what people search for ("tornjak lifespan") in the result itself.
  def breed_page_title(breed)
    life = breed_life_span(breed)
    pictures = breed.breed_images.any? ? " and Pictures" : ""

    life ? "#{breed.name}: Size, Life Span (#{life})#{pictures}" : "#{breed.name} Dog Breed: Size#{pictures}"
  end

  def breed_page_description(breed)
    facts = []
    facts << "lives #{breed_life_span(breed)}" if breed_life_span(breed)
    facts << "weighs #{breed_weight_range(breed)}" if breed_weight_range(breed)
    facts << breed.group.name if breed.group
    facts << (breed.hypoallergenic ? "hypoallergenic" : "not hypoallergenic")

    extras = breed.breed_images.any? ? "Pictures and free" : "Free"
    "#{breed.name} facts: #{facts.join(", ")}. #{extras} JSON data from the Dog API."
  end

  # Both sexes folded into one range, for places with room for one number.
  def breed_weight_range(breed)
    values = [breed.male_weight_min, breed.male_weight_max, breed.female_weight_min, breed.female_weight_max].compact
    return if values.empty?

    min, max = values.minmax
    (min == max) ? "#{min} kg" : "#{min}–#{max} kg"
  end

  def breed_height_range(breed)
    values = [breed.male_height_min, breed.male_height_max, breed.female_height_min, breed.female_height_max].compact
    return if values.empty?

    min, max = values.minmax
    (min == max) ? "#{min} cm" : "#{min}–#{max} cm"
  end

  def breed_size_sentence(breed)
    male = breed_weight(breed, :male)
    female = breed_weight(breed, :female)
    return if male.nil? && female.nil?

    if male && female && male != female
      "Males weigh #{male} and females #{female}."
    else
      "Adults weigh #{male || female}."
    end
  end

  def breed_summary(breed)
    sentences = []
    sentences << breed_group_sentence(breed) if breed.group
    sentences << "It comes from #{breed_origin(breed)}." if breed_origin(breed)
    sentences << breed_size_sentence(breed)
    height = breed_height_range(breed)
    sentences << "It stands #{height} tall." if height
    sentences << "It typically lives #{breed_life_span(breed)}." if breed_life_span(breed)
    sentences << "It is #{"not " unless breed.hypoallergenic}considered hypoallergenic."
    sentences.compact.join(" ")
  end

  # The groups are the AKC's, and two of them are steps towards recognition
  # rather than groups a breed belongs to, so they read as what they are.
  def breed_group_sentence(breed)
    case breed.group.name
    when "Foundation Stock Service"
      "The #{breed.name} is recorded in the AKC's Foundation Stock Service, where breeds wait before full recognition."
    when "Miscellaneous Class"
      "The #{breed.name} is in the AKC's Miscellaneous Class, the last step before full recognition."
    else
      "The #{breed.name} is in the AKC's #{breed.group.name}."
    end
  end

  # Only questions the record can answer.
  def breed_faq(breed)
    faq = []
    if (life = breed_life_span(breed))
      faq << ["How long does a #{breed.name} live?", "The #{breed.name} has a life span of #{life}."]
    end
    if (weight = breed_weight_range(breed))
      height = breed_height_range(breed)
      answer = "#{breed_size_sentence(breed)}#{" Height ranges from #{height}." if height}"
      faq << ["How big does a #{breed.name} get?", answer] if weight
    end
    faq << ["Is the #{breed.name} hypoallergenic?",
      breed.hypoallergenic ? "Yes, the #{breed.name} is considered hypoallergenic." : "No, the #{breed.name} is not considered hypoallergenic."]
    if breed.group
      faq << ["What group is the #{breed.name} in?", breed_group_sentence(breed)]
    end
    faq
  end

  def breed_faq_structured_data(faq)
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => faq.map do |question, answer|
        {"@type" => "Question", "name" => question, "acceptedAnswer" => {"@type" => "Answer", "text" => answer}}
      end
    }
  end
end
