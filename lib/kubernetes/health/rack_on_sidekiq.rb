require 'rack'
require 'prometheus/client'
require 'prometheus/client/formats/text'

module Kubernetes
  module Health
    class RackOnSidekiq
      def call(env)
        req = ::Rack::Request.new(env)
        content = ''
        type = ::Kubernetes::Health::Config.response_format == 'json' ? { 'Content-Type' => 'application/json' } : { 'Content-Type' => 'text/plain' }
        case req.path_info
        when Kubernetes::Health::Config.route_metrics
          http_code = 200

          sidekiq_metrics = generate_sidekiq_metrics

          if ::Kubernetes::Health::Config.response_format == 'json'
            content = sidekiq_metrics.to_json
          else
            prometheus_registry = generate_prometheus_registry
            prometheus_registry.get(:sidekiq_capacity).set({}, sidekiq_metrics[:sidekiq_capacity])
            prometheus_registry.get(:sidekiq_busy).set({}, sidekiq_metrics[:sidekiq_busy])
            prometheus_registry.get(:sidekiq_usage).set({}, sidekiq_metrics[:sidekiq_usage])
            content = Prometheus::Client::Formats::Text.marshal(prometheus_registry)
          end
        else
          http_code = 404
        end
        ::Kubernetes::Health::Config.request_log_callback.call(req, http_code, content)

        [http_code, type, [content]]
      end

      def generate_prometheus_registry
        prometheus_registry = Prometheus::Client.registry
        prometheus_registry.gauge(:sidekiq_capacity, 'Sidekiq Threads Number', index: 0)
        prometheus_registry.gauge(:sidekiq_busy, 'Sidekiq Busy Threads', index: 0)
        prometheus_registry.gauge(:sidekiq_usage, 'Result of sidekiq_busy/sidekiq_capacity', index: 0)
        prometheus_registry
      end

      def generate_sidekiq_metrics
        sidekiq_info = Sidekiq::ProcessSet.new.to_a.filter { |p| p.identity == Sidekiq.options[:identity] }

        stats = {
          sidekiq_capacity: Sidekiq.options[:concurrency],
          sidekiq_busy: sidekiq_info.size.zero? ? 0 : sidekiq_info[0]['busy']
        }

        stats[:sidekiq_usage] = (stats[:sidekiq_busy] / stats[:sidekiq_capacity].to_f).round(2)
        stats
      end
    end
  end
end