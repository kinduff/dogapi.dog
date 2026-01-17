# frozen_string_literal: true

puts "Started seeding the database..."

FACTS = [
  'More than 1 in 3 American families own a dog',
  'A dog\'s nose print is unique, just like a human\'s fingerprint',
  'Dogs have a unique way of showing affection, called a "butt wag," where they wag their tail and wiggle their rear end.',
  'Old England, the word "hound" was used to refer to all types of dogs.',
  "A dog's nose is so sensitive that they can detect minute changes in the earth's magnetic field"
]

GROUP_NAMES = [
  "Foundation Stock Service",
  "Herding Group",
  "Hound Group",
  "Non-Sporting Group",
  "Sporting Group",
  "Terrier Group",
  "Toy Group",
  "Working Group",
  "Miscellaneous Class"
].freeze

BREEDS = [
  "Caucasian Shepherd Dog",
  "Bouvier des Flandres",
  "Grand Basset Griffon Vendéen",
  "Hokkaido",
  "Japanese Terrier",
  "Hanoverian Scenthound",
  "Tibetan Spaniel",
  "Border Collie",
  "Curly-Coated Retriever"
].freeze

FACTS.each do |fact|
  Fact.find_or_create_by(body: fact)
end

GROUP_NAMES.each do |group_name|
  Group.find_or_create_by(name: group_name)
end

group_ids = Group.all.map(&:id)

BREEDS.each do |breed|
  Breed.find_or_create_by(
    name: breed,
    description: "Lorem ipsum",
    life: {
      max: rand(15..20),
      min: rand(10..15)
    },
    male_weight: {
      max: rand(50..80),
      min: rand(35..50)
    },
    female_weight: {
      max: rand(30..55),
      min: rand(20..30)
    },
    hypoallergenic: [true, false].sample,
    group_id: group_ids.sample
  )
end

puts "Seeding finished!"
