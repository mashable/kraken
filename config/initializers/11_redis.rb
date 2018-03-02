require 'benchmark'

redis_conf = Soles.configuration.value("redis").deep_symbolize_keys
if ENV['DEBUG']
  redis_conf[:logger] = Logger.new($stderr)
  redis_conf[:logger].formatter = ::Sidekiq::Logging::Pretty.new
end

Sidekiq.configure_client do |config|
  config.logger = Soles.logger

  config.redis = redis_conf
end

module ::Sidekiq
  module Middleware
    class TelegrafLogger
      def call(_worker, msg, _queue)
        klass = msg['class'].underscore
        Kraken.config.telegraf.increment "job.run", worker: klass
        Kraken.config.telegraf.timing("job.duration", nil, worker: klass) { yield }
        Kraken.config.telegraf.increment "job.success", worker: klass
      rescue StandardError => e
        Kraken.config.telegraf.increment "job.failure", worker: klass
        raise
      end
    end
  end
end

Sidekiq.configure_server do |config|
  config.logger = Soles.logger
  Soles.logger.formatter = ::Sidekiq::Logging::Pretty.new
  config.redis = redis_conf
  config.server_middleware do |chain|
    chain.add ::Sidekiq::Middleware::TelegrafLogger
  end
end

Soles.configuration.redis = ConnectionPool.new(size: Soles.configuration.value("redis.workers", 16), timeout: 5) do
  Redis.new redis_conf
end