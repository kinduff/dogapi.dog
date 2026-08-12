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

  desc "Import images for every breed that has none: images:import_all[wikimedia_commons,3]"
  task :import_all, %i[source limit] => :environment do |_task, args|
    breeds = Breed.where.missing(:breed_images).order(:name)
    puts "#{breeds.size} breeds without images"

    totals = Hash.new(0)

    breeds.each_with_index do |breed, index|
      result = run_import(breed, args)
      totals[:imported] += result.imported.size
      totals[:skipped] += result.skipped.size
      totals[:errors] += result.errors.size

      puts "[#{index + 1}/#{breeds.size}] #{breed.name}: #{result.summary}"
      result.errors.each { |error| warn "  #{error}" }

      sleep import_delay unless index == breeds.size - 1
    end

    puts "Done: #{totals[:imported]} imported, #{totals[:skipped]} skipped, #{totals[:errors]} failed"
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
end
