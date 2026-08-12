# frozen_string_literal: true

require "net/http"

namespace :dev do
  desc "Replace local groups and breeds with the ones the production API serves"
  task seed_from_production: :environment do
    abort("Refusing to run outside development") unless Rails.env.development?

    base = ENV.fetch("PRODUCTION_API", "https://dogapi.dog/api/v2")
    groups = fetch("#{base}/groups")
    breeds = fetch("#{base}/breeds?page%5Bsize%5D=1000")

    puts "Fetched #{groups.size} groups and #{breeds.size} breeds from #{base}"

    # Production ids are kept, so anything that refers to a breed by id, the
    # docs examples included, points at the same record in both places.
    ActiveRecord::Base.transaction do
      BreedImage.find_each(&:destroy)
      Breed.delete_all
      Group.delete_all

      Group.insert_all!(groups.map { |group| {id: group["id"], name: group.dig("attributes", "name")} })
      Breed.insert_all!(breeds.map { |breed| breed_row(breed) })
    end

    puts "Local database now has #{Group.count} groups and #{Breed.count} breeds"
  end

  desc "Forget every stored image locally, without touching the remote bucket"
  task reset_images: :environment do
    abort("Refusing to run outside development") unless Rails.env.development?

    blobs = ActiveStorage::Blob.group(:service_name).count
    disk_root = Rails.root.join("storage")

    # delete_all rather than purge: a blob recorded against a bucket cannot be
    # purged without that bucket's credentials, and the point here is to get
    # rid of the rows on a machine that has none. Objects already uploaded to
    # a bucket are left where they are.
    ActiveStorage::VariantRecord.delete_all
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
    BreedImage.delete_all

    FileUtils.rm_rf(Dir.glob(disk_root.join("*"))) if disk_root.exist?

    puts "Removed #{blobs.map { |service, count| "#{count} #{service}" }.join(", ")} blobs and emptied storage/"
    puts "Run `rails images:import_all` to fill it again, on local disk this time"
  end

  def fetch(url)
    response = Net::HTTP.get_response(URI.parse(url))
    abort("#{response.code} #{response.message} from #{url}") unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("data")
  end

  def breed_row(breed)
    attributes = breed.fetch("attributes")
    now = Time.current

    {
      id: breed["id"],
      group_id: breed.dig("relationships", "group", "data", "id"),
      name: attributes["name"],
      description: attributes["description"],
      hypoallergenic: attributes["hypoallergenic"],
      life: attributes["life"] || {},
      male_weight: attributes["male_weight"] || {},
      female_weight: attributes["female_weight"] || {},
      created_at: now,
      updated_at: now
    }
  end
end
