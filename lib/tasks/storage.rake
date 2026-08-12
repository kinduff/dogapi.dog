# frozen_string_literal: true

namespace :storage do
  desc "Upload, read back and delete a small file, to check bucket credentials"
  task :check, [:service] => :environment do |_task, args|
    name = (args[:service].presence || ENV.fetch("ACTIVE_STORAGE_SERVICE", "local")).to_sym
    # storage.yml lists services, not environments, so it is read as a plain
    # ERB template rather than through config_for.
    configurations = YAML.safe_load(ERB.new(Rails.root.join("config/storage.yml").read).result, aliases: true)
    service = ActiveStorage::Service.configure(name, configurations.deep_symbolize_keys)
    key = "connectivity-check-#{SecureRandom.hex(6)}"
    body = "ok"

    puts "Service: #{name} (#{service.class.name.demodulize})"

    service.upload(key, StringIO.new(body), checksum: OpenSSL::Digest::MD5.base64digest(body), content_type: "text/plain")
    puts "Uploaded #{key}"

    ActiveStorage::Current.url_options = Rails.application.config.x.image_url_options

    puts "Downloaded: #{service.download(key).inspect}"
    puts "Public URL: #{service.url(key, filename: ActiveStorage::Filename.new("check.txt"), content_type: "text/plain", disposition: :inline)}"
  ensure
    if service && key
      service.delete(key)
      puts "Deleted #{key}"
    end
  end
end
