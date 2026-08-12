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

  # Every request pays for the model's own web searches, so a long run is
  # deliberately unhurried.
  def enrich_delay = ENV.fetch("ENRICHMENT_DELAY", "1").to_f

  def enrich_flags(args)
    flags = Array(args.extras) + [args[:flags]].compact
    {dry_run: flags.include?("dry"), overwrite: flags.include?("overwrite")}
  end

  def enrich(breed, flags)
    record = BreedEnrichments::Run.call(breed, **flags)
    puts enrich_summary(breed, record, flags)
    record
  end

  def enrich_summary(breed, record, flags)
    changes = record.payload.fetch("changes", {})
    parts = ["#{breed.name}: #{changes.empty? ? "no change" : "#{changes.size} fields"}"]
    parts << "confidence #{record.confidence}" if record.confidence
    parts << "#{record.rejections.size} rejected" if record.rejections.any?
    parts << "(dry run)" if flags[:dry_run]
    parts.join(", ")
  end

  desc "Research one breed: breeds:enrich[Akita,dry]"
  task :enrich, %i[breed flags] => :environment do |_task, args|
    name = args[:breed] or abort("Usage: rails breeds:enrich[BreedName]")
    breed = Breed.find_by(name: name) or abort("No breed named #{name.inspect}")

    record = enrich(breed, enrich_flags(args))

    puts JSON.pretty_generate(record.payload.fetch("changes", {}))
    record.rejections.each { |rejection| warn "  rejected #{rejection["field"]}: #{rejection["reason"]}" }
    corrections = record.raw_response["corrections"]
    puts "corrections offered: #{corrections.to_json}" if corrections.present?
  end

  desc "Research every breed that has not been enriched yet: breeds:enrich_all[dry]"
  task :enrich_all, %i[flags] => :environment do |_task, args|
    flags = enrich_flags(args)
    breeds = flags[:overwrite] ? Breed.order(:name) : Breed.unenriched.order(:name)
    totals = Hash.new(0)

    puts "#{breeds.size} breeds to research with #{BreedEnrichments.model}"

    breeds.each_with_index do |breed, index|
      # One breed going wrong — a refusal, a timeout, a bad answer — must not
      # cost the rest of the run.
      begin
        record = enrich(breed, flags)
      rescue => e
        totals[:failed] += 1
        warn "[#{index + 1}/#{breeds.size}] #{breed.name}: #{e.class}: #{e.message}"
        next
      end

      totals[record.applied? ? :applied : :skipped] += 1
      totals[:rejections] += record.rejections.size

      sleep enrich_delay unless index == breeds.size - 1
    end

    puts "Done: #{totals[:applied]} applied, #{totals[:skipped]} unchanged, " \
         "#{totals[:failed]} failed, #{totals[:rejections]} fields rejected"
  end

  desc "Show how much of the breed data is filled in"
  task enrich_stats: :environment do
    total = Breed.count

    puts "#{Breed.enriched.count}/#{total} breeds enriched"

    BreedEnrichments::Applier::COLUMNS.each do |column|
      # Empty jsonb objects, empty jsonb arrays and empty text arrays all
      # render as one of these, whatever the column's type.
      filled = Breed.where("#{column}::text NOT IN ('{}', '[]', 'null')").count
      puts format("  %-15s %3d/%d", column, filled, total)
    end
  end

  desc "List the runs a human should look at: low confidence, rejections or corrections"
  task enrich_review: :environment do
    runs = BreedEnrichment.includes(:breed).ordered.select do |run|
      run.confidence != "high" || run.rejections.any? || run.raw_response["corrections"].present?
    end

    puts "#{runs.size} runs worth reviewing"

    runs.each do |run|
      puts "\n#{run.breed.name} (#{run.model}, confidence #{run.confidence || "unknown"})"
      run.rejections.each { |rejection| puts "  rejected #{rejection["field"]}: #{rejection["reason"]}" }
      corrections = run.raw_response["corrections"]
      puts "  corrections: #{corrections.to_json}" if corrections.present?
      Array(run.payload["sources"]).each { |source| puts "  source: #{source["url"]}" }
    end
  end
end
