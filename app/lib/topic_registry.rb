require 'socket'
require 'etc'

class TopicRegistry
  def self.bucket_prefix
    case Soles.environment
    when "development", "test"
      "#{Soles.environment}/#{Etc.getlogin}@#{Socket.gethostname}"
    else
      Soles.environment
    end
  end

  S3_DEFAULTS = {
    "connector.class" => "io.confluent.connect.s3.S3SinkConnector",
    "storage.class" => "io.confluent.connect.s3.storage.S3Storage",
    "partitioner.class" => "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "path.format" => "'year'=YYYY/'month'=MM/'day'=dd",
    "locale" => "US",
    "timezone" => "UTC",
    "timestamp.extractor" => "Wallclock",
    "partition.duration.ms" => (86400 * 1000), # One day
    "schema.generator.class" => "io.confluent.connect.storage.hive.schema.TimeBasedSchemaGenerator",
    "schema.compatibility" => "none",
    "flush.size" => 1_000_000,
    "rotate.interval.ms" => 1.hour * 1000,  # This configuration option is only available for Kafka 3.3.0+. It won't work with the Landoop 3.2.2 setup.
    "tasks.max" => 1,
    "s3.bucket.name" => Kraken.config.value("aws.bucket"),
    "s3.region" => Kraken.config.value("aws.credentials.region"),
    # "rotate.schedule.interval.ms" => 3600000,
  }

  DEFAULTS = {
    s3_json: S3_DEFAULTS.merge(
      "format.class" => "io.confluent.connect.s3.format.json.JsonFormat",
      "topics.dir" => "#{TopicRegistry.bucket_prefix}/json"
    ),
    s3_avro: S3_DEFAULTS.merge(
      "format.class" => "io.confluent.connect.s3.format.avro.AvroFormat",
      "topics.dir" => "#{TopicRegistry.bucket_prefix}/avro"
    ),
  }

  def initialize
    @sinks = {}
  end

  def config(key)
    DEFAULTS[key].dup
  end

  attr_reader :sinks

  def register(name_or_options, topics = [])
    topics = topics[:topics] if topics.is_a? Hash
    options = nil
    case name_or_options
    when String, Symbol
      name = name_or_options.to_sym
      options = DEFAULTS[name_or_options]
    when Hash
      options = name_or_options.dup
      name = options.delete :name
    end
    raise "Missing name" unless name.present?
    @sinks[name] ||= options
    @sinks[name][:topics] ||= []
    @sinks[name][:topics] |= Array(topics)
  end

  def generate_registries!
    @sinks.each do |name, config|
      config = config.dup
      config[:topics] = config[:topics].map {|t| "kraken.#{t}" }.join(",")
      register_config name, config
    end
  end

  def cleanup_registries!
    @sinks.each do |name, config|
      delete_config name
    end
  end

  private

  def delete_config(name)
    resp = conn.delete("/connectors/#{name}") do |req|
      req.headers['Content-Type'] = "application/json"
    end
    if (200..299).cover? resp.status
      Soles.logger.info "[#{name}] Successfully deleted!"
    else
      Soles.logger.error "[#{name}] Failed to delete config (#{resp.status} - #{resp.body})"
    end
  end

  def register_config(name, config)
    resp = conn.put("/connectors/#{name}/config", config.to_json) do |req|
      req.headers['Content-Type'] = "application/json"
    end
    if (200..299).cover? resp.status
      Soles.logger.info "[#{name}] Successfully registered!"
    else
      Soles.logger.error "[#{name}] Failed to update config (#{resp.status} - #{resp.body})"
    end
  end

  def get_config(options)
    opt = case options
    when Hash
      options.dup
    when Symbol
      DEFAULTS[options].dup
    end
  end

  def conn
    @conn ||= begin
      servers = Array(Kraken.config.value("kafka.connect"))
      Faraday.new(servers.sample) do |faraday|
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end