# Metrics for the observer stack. Every process (Puma, Sidekiq) pushes to the
# prometheus_exporter collector, the "metrics" service in docker-compose.yml,
# which Alloy scrapes. Nothing happens unless PROMETHEUS_EXPORTER_HOST is set,
# so development and the test suite stay untouched.
return if ENV["PROMETHEUS_EXPORTER_HOST"].blank?

require "prometheus_exporter/client"
require "prometheus_exporter/middleware"
require "prometheus_exporter/instrumentation"

PrometheusExporter::Client.default = PrometheusExporter::Client.new(
  host: ENV["PROMETHEUS_EXPORTER_HOST"],
  port: ENV.fetch("PROMETHEUS_EXPORTER_PORT", 9394).to_i
)

process_type = Sidekiq.server? ? "sidekiq" : "web"

Rails.application.middleware.unshift PrometheusExporter::Middleware
PrometheusExporter::Instrumentation::Process.start(type: process_type)
PrometheusExporter::Instrumentation::ActiveRecord.start(custom_labels: {type: process_type}, config_labels: [:database])

if Sidekiq.server?
  Sidekiq.configure_server do |config|
    config.server_middleware { |chain| chain.add PrometheusExporter::Instrumentation::Sidekiq }
    config.death_handlers << PrometheusExporter::Instrumentation::Sidekiq.death_handler
    config.on(:startup) do
      PrometheusExporter::Instrumentation::SidekiqProcess.start
      PrometheusExporter::Instrumentation::SidekiqQueue.start
      PrometheusExporter::Instrumentation::SidekiqStats.start
    end
  end
end
