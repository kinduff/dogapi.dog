# frozen_string_literal: true

namespace :images do
  # Wikimedia asks clients not to hammer the API. Imports are occasional, so
  # a pause between breeds costs nothing.
  def import_delay = ENV.fetch("IMAGE_IMPORT_DELAY", "1").to_f

  desc "Import images for one breed: images:import[Akita,wikimedia_commons,3]"
  task :import, %i[breed source limit] => :environment do |_task, args|
    name = args[:breed] or abort("Usage: rails images:import[BreedName]")
    breed = Breed.find_by(name: name) or abort("No breed named #{name.inspect}")

    puts run_import(breed, args).summary
  end

  desc "Bring every breed up to the requested number of images: images:import_all[wikimedia_commons,3]"
  task :import_all, %i[source limit] => :environment do |_task, args|
    limit = (args[:limit].presence || 3).to_i

    # Breeds that are short of the target, not just the ones with nothing: the
    # limit is how many images a breed should end up with.
    breeds = Breed.left_joins(:breed_images)
      .group(:id)
      .having("COUNT(breed_images.id) < ?", limit)
      .order(:name)
      .to_a

    puts "#{breeds.size} breeds with fewer than #{limit} images"

    totals = Hash.new(0)

    breeds.each_with_index do |breed, index|
      # A long run must survive one breed going wrong, whatever the reason.
      begin
        result = run_import(breed, args)
      rescue => e
        totals[:errors] += 1
        warn "[#{index + 1}/#{breeds.size}] #{breed.name}: #{e.class}: #{e.message}"
        next
      end

      totals[:imported] += result.imported.size
      totals[:skipped] += result.skipped.size
      totals[:errors] += result.errors.size

      puts "[#{index + 1}/#{breeds.size}] #{breed.name}: #{result.summary}"
      result.errors.each { |error| warn "  #{error}" }

      sleep import_delay unless index == breeds.size - 1
    end

    puts "Done: #{totals[:imported]} imported, #{totals[:skipped]} skipped, #{totals[:errors]} failed"
  end

  desc "Walk every source in turn until each breed has enough images: images:backfill[3]"
  task :backfill, [:limit] => :environment do |_task, args|
    limit = (args[:limit].presence || 3).to_i

    BreedImages::SOURCE_ORDER.each do |source|
      short = breeds_short_of(limit)

      if short.empty?
        puts "Every breed has #{limit} images; nothing left for #{source}"
        break
      end

      puts "#{source}: #{short.size} breeds with fewer than #{limit} images"
      totals = import_each(short, source, limit)
      puts "#{source}: #{totals[:imported]} imported, #{totals[:skipped]} skipped, #{totals[:errors]} failed"
    end

    puts "#{Breed.where.associated(:breed_images).distinct.count}/#{Breed.count} breeds have images"
  end

  desc "Queue the backfill instead of running it here: images:backfill_async[10]"
  task :backfill_async, [:limit] => :environment do |_task, args|
    limit = (args[:limit].presence || 3).to_i
    breeds = breeds_short_of(limit)
    first_source = BreedImages::SOURCE_ORDER.first

    # One job per breed, not per breed and source: each job walks its breed on
    # to the next source itself, so the queue holds hundreds of jobs rather
    # than thousands, and a breed never asks two sources at once.
    breeds.each { |breed| BreedImageImportJob.perform_later(breed.id, first_source, limit) }

    puts "Queued #{breeds.size} breeds for #{limit} images each, starting at #{first_source}"
    puts "Each imported image is queued for review as it lands"
  end

  desc "Queue a review of every unscored image: images:rerank_async[force]"
  task :rerank_async, [:force] => :environment do |_task, args|
    force = args[:force].present?
    scope = force ? BreedImage.all : BreedImage.where(reviewed_at: nil)

    scope.find_each { |image| BreedImageReviewJob.perform_later(image.id, force: force) }

    puts "Queued #{scope.count} images for review"
  end

  desc "Score one breed's images and put the best first: images:rerank[Akita,force]"
  task :rerank, %i[breed force] => :environment do |_task, args|
    name = args[:breed] or abort("Usage: rails images:rerank[BreedName]")
    breed = Breed.find_by(name: name) or abort("No breed named #{name.inspect}")

    result = BreedImages::Reranker.call(breed, force: args[:force].present?)

    puts "#{breed.name}: #{result.summary}"
    result.reviewed.each { |image| puts "  #{image.score}/10 #{image.source_id}: #{image.review_notes}" }
    result.errors.each { |error| warn "  #{error}" }
  end

  desc "Score every breed's images and put the best first: images:rerank_all[force]"
  task :rerank_all, [:force] => :environment do |_task, args|
    force = args[:force].present?

    # Without `force` a breed whose pictures were all scored already has
    # nothing to ask the model, so a rerun costs one query per breed.
    breeds = Breed.where.associated(:breed_images).distinct.order(:name).to_a
    puts "#{breeds.size} breeds with images"

    totals = Hash.new(0)

    breeds.each_with_index do |breed, index|
      begin
        result = BreedImages::Reranker.call(breed, force: force)
      rescue => e
        totals[:errors] += 1
        warn "[#{index + 1}/#{breeds.size}] #{breed.name}: #{e.class}: #{e.message}"
        next
      end

      totals[:reviewed] += result.reviewed.size
      totals[:skipped] += result.skipped.size
      totals[:errors] += result.errors.size

      puts "[#{index + 1}/#{breeds.size}] #{breed.name}: #{result.summary}"
      result.errors.each { |error| warn "  #{error}" }
    end

    puts "Done: #{totals[:reviewed]} reviewed, #{totals[:skipped]} skipped, #{totals[:errors]} failed"
  end

  desc "Delete reviewed images that scored below a threshold: images:prune_reviewed[4]"
  task :prune_reviewed, [:score] => :environment do |_task, args|
    threshold = (args[:score].presence || BreedImages::Reviewer::GOOD_ENOUGH - 2).to_i
    doomed = BreedImage.where(score: ...threshold).includes(:breed).order(:score)

    doomed.find_each do |image|
      puts "#{image.breed.name} (#{image.source_id}): #{image.score}/10 #{image.review_notes}"
    end

    removed = doomed.destroy_all.size
    puts "Removed #{removed} images below #{threshold}/10, #{BreedImage.count} left"
  end

  desc "Report how the reviewed images scored"
  task scores: :environment do
    reviewed = BreedImage.where.not(score: nil)
    puts "#{reviewed.count}/#{BreedImage.count} images reviewed"

    reviewed.group(:score).count.sort.reverse_each do |score, count|
      puts "  #{score.to_s.rjust(2)}/10  #{"#" * [count, 60].min} #{count}"
    end

    unreviewable = Breed.where.associated(:breed_images).distinct.count -
      Breed.joins(:breed_images).where(breed_images: {score: BreedImages::Reviewer::GOOD_ENOUGH..}).distinct.count
    puts "#{unreviewable} breeds have no image scoring #{BreedImages::Reviewer::GOOD_ENOUGH}/10 or better"
  end

  desc "Delete stored images that fall below the current quality floor"
  task prune: :environment do
    removed = 0

    BreedImage.with_files.find_each do |image|
      next unless image.file.attached?

      image.file.blob.analyze unless image.file.blob.analyzed?
      next if image.valid?

      puts "#{image.breed.name} (#{image.source_id}): #{image.errors[:file].join(", ")}"
      image.destroy
      removed += 1
    end

    puts "Removed #{removed} images, #{BreedImage.count} left"
  end

  desc "Build any missing variants for stored images"
  task reprocess: :environment do
    processed = 0

    BreedImage.with_files.find_each do |image|
      next unless image.file.attached?

      BreedImage::VARIANTS.each_key { |name| image.file.variant(name).processed }
      processed += 1
    rescue => e
      warn "#{image.breed.name} (#{image.source_id}): #{e.message}"
    end

    puts "Reprocessed #{processed} images"
  end

  desc "Show how many breeds have images"
  task stats: :environment do
    with_images = Breed.where.associated(:breed_images).distinct.count
    total = Breed.count

    puts "#{with_images}/#{total} breeds have images, #{BreedImage.count} images stored"
  end

  def run_import(breed, args)
    BreedImages::Importer.call(
      breed,
      source: args[:source].presence || BreedImages::DEFAULT_SOURCE,
      limit: (args[:limit].presence || 3).to_i
    )
  end

  # Breeds that are short of the target, not just the ones with nothing: the
  # limit is how many images a breed should end up with.
  def breeds_short_of(limit)
    Breed.left_joins(:breed_images)
      .group(:id)
      .having("COUNT(breed_images.id) < ?", limit)
      .order(:name)
      .to_a
  end

  def import_each(breeds, source, limit)
    totals = Hash.new(0)

    breeds.each_with_index do |breed, index|
      # A long run must survive one breed going wrong, whatever the reason.
      begin
        result = BreedImages::Importer.call(breed, source: source, limit: limit)
      rescue => e
        totals[:errors] += 1
        warn "[#{index + 1}/#{breeds.size}] #{breed.name}: #{e.class}: #{e.message}"
        next
      end

      totals[:imported] += result.imported.size
      totals[:skipped] += result.skipped.size
      totals[:errors] += result.errors.size

      puts "[#{index + 1}/#{breeds.size}] #{breed.name}: #{result.summary}"
      result.errors.each { |error| warn "  #{error}" }

      sleep import_delay unless index == breeds.size - 1
    end

    totals
  end
end
