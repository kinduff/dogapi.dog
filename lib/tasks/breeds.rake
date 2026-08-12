# frozen_string_literal: true

namespace :breeds do
  # What the API promises: weights in kilograms, life expectancy in years. A
  # value outside these bounds is not a rare breed, it is a bad row.
  def plausible_ranges
    {
      "life" => (5..25),
      "male_weight" => (0.5..115),
      "female_weight" => (0.5..115)
    }
  end

  desc "Report breeds whose stored ranges are missing, inverted or implausible"
  task audit: :environment do
    problems = Hash.new { |hash, key| hash[key] = [] }

    Breed.includes(:group).order(:name).find_each do |breed|
      problems[:no_description] << breed.name if breed.description.blank?

      plausible_ranges.each do |field, bounds|
        range = breed.public_send(field)
        min, max = range.values_at("min", "max")

        next problems[:"missing_#{field}"] << breed.name if min.nil? || max.nil?

        problems[:"inverted_#{field}"] << "#{breed.name} (#{min}-#{max})" if min > max
        next if bounds.cover?(min) && bounds.cover?(max)

        problems[:"implausible_#{field}"] << "#{breed.name} (#{min}-#{max}, expected #{bounds})"
      end

      # Males of most breeds are heavier than females. An exact match across
      # both ranges usually means one was copied from the other rather than
      # looked up, which is worth knowing before enrichment overwrites it.
      problems[:identical_weights] << breed.name if breed.male_weight == breed.female_weight
    end

    duplicates = Breed.group(:name).having("COUNT(*) > 1").count
    duplicates.each { |name, count| problems[:duplicate_name] << "#{name} (#{count})" }

    puts "#{Breed.count} breeds in #{Group.count} groups"

    if problems.empty?
      puts "Nothing to report"
      next
    end

    problems.each do |kind, names|
      puts "\n#{kind} (#{names.size})"
      names.each { |name| puts "  #{name}" }
    end
  end
end
