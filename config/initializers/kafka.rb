require 'kafka'
require 'avro_turf/messaging'
config = Kraken.config

if Kraken.standalone?
  config.kafka_producer = KafkaFacade.new
else
  config.kafka = ::Concurrent::ThreadLocalVar.new do
    Kafka.new(
      # At least one of these nodes must be available:
      seed_brokers: config.value('kafka.seeds'),

      # Set an optional client id in order to identify the client to Kafka:
      client_id: config.value('kafka.client_id')
    )
  end

  config.kafka_producer = config.kafka.value.async_producer(
    max_queue_size: 15_000,
    max_buffer_bytesize: 200_000_000,
    delivery_threshold: 100,
    delivery_interval: 30
  )

  Soles.on_exit do
    config.kafka_producer.deliver_messages
    config.kafka_producer.shutdown
  end
end

configuration.topic_registry = TopicRegistry.new
