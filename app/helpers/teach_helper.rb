# frozen_string_literal: true

module TeachHelper
  # The link a teacher hands out. Umami reads UTM parameters on its own, so a
  # class arriving through it shows up as a class instead of as "direct".
  CLASSROOM_UTM = {utm_source: "classroom", utm_medium: "course", utm_campaign: "teach"}.freeze

  def classroom_link
    "#{request.base_url}/?#{CLASSROOM_UTM.to_query}"
  end

  # The page as a free learning resource, so a search for course material can
  # tell it apart from the reference docs.
  def teach_structured_data
    structured_data(
      "@context" => "https://schema.org",
      "@type" => "LearningResource",
      "name" => "Teaching with the Dog API",
      "description" => "Free classroom exercises and starter code for fetching JSON from a keyless, CORS-open dog API.",
      "url" => "#{request.base_url}#{teach_path}",
      "inLanguage" => "en",
      "isAccessibleForFree" => true,
      "learningResourceType" => ["Exercise", "Tutorial"],
      "educationalLevel" => ["Beginner", "Intermediate"],
      "teaches" => ["HTTP requests", "JSON", "REST APIs", "JSON:API", "Pagination", "fetch()"],
      "audience" => {"@type" => "EducationalAudience", "educationalRole" => "teacher"},
      "author" => {"@type" => "Person", "name" => "kinduff"},
      "publisher" => {"@type" => "Organization", "name" => "Dog API", "url" => "#{request.base_url}/"}
    )
  end
end
