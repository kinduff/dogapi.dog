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

  # A breed takes one to three minutes, nearly all of it spent waiting on the
  # model's own web searches, so the whole catalogue takes hours in a single
  # file. The work is per-breed independent, so run several at once.
  # A thread needs the database only for the moment it writes, but it still
  # has to be able to check a connection out, so the pool is the ceiling.
  def enrich_workers
    pool = ActiveRecord::Base.connection_pool.size
    asked = ENV.fetch("ENRICHMENT_WORKERS", "4").to_i.clamp(1, 20)
    workers = asked.clamp(1, [pool - 1, 1].max)

    if workers < asked
      warn "Running #{workers} at a time, not #{asked}: the pool holds #{pool} connections. " \
           "Raise RAILS_MAX_THREADS to go wider."
    end

    workers
  end

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
    # A whole catalogue is hours and real money, so a run can be capped while
    # the prompt is still being tuned.
    breeds = breeds.limit(ENV["ENRICHMENT_LIMIT"].to_i) if ENV["ENRICHMENT_LIMIT"].present?
    breeds = breeds.to_a
    totals = Hash.new(0)

    workers = enrich_workers
    queue = Queue.new
    breeds.each { |breed| queue << breed }
    done = 0
    lock = Mutex.new

    puts "#{breeds.size} breeds to research with #{BreedEnrichments.model}, #{workers} at a time"

    threads = Array.new(workers) do
      Thread.new do
        # Each thread checks out its own connection, and gives it back rather
        # than holding one for the minutes it spends waiting on the API.
        loop do
          breed =
            begin
              queue.pop(true)
            rescue ThreadError
              break
            end

          outcome =
            begin
              # One breed going wrong — a refusal, a timeout, a bad answer —
              # must not cost the rest of the run.
              record = enrich(breed, flags)
              [record.applied? ? :applied : :skipped, record.rejections.size]
            rescue => e
              warn "#{breed.name}: #{e.class}: #{e.message}"
              [:failed, 0]
            ensure
              # Most of a breed is spent waiting on the API, and holding a
              # connection through that would starve the other threads.
              ActiveRecord::Base.connection_pool.release_connection
            end

          lock.synchronize do
            done += 1
            totals[outcome.first] += 1
            totals[:rejections] += outcome.last
            puts "[#{done}/#{breeds.size}]" if (done % 25).zero?
          end
        end
      end
    end

    threads.each(&:join)

    verb = flags[:dry_run] ? "would fill in" : "filled in"

    puts "Done: #{verb} #{totals[:applied]}, #{totals[:skipped]} unchanged, " \
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

    runs = BreedEnrichment.count
    next if runs.zero?

    usage = BreedEnrichment.pluck(Arel.sql("payload -> 'usage'")).compact
    tokens = %w[input_tokens output_tokens].to_h do |field|
      [field, usage.sum { |entry| entry[field].to_i }]
    end
    searches = usage.sum { |entry| entry.dig("server_tool_use", "web_search_requests").to_i }

    puts "\n#{runs} runs: #{tokens["input_tokens"]} tokens in, #{tokens["output_tokens"]} out, #{searches} web searches"
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
