class KafkaFacade
  def produce(payload, options = {})
    topic = options[:topic] || "topic.default"
    Kraken.config.redis.with do |r|
      key = "kraken.topic:#{topic}"
      r.lpush key, payload
      r.expire key, 3600
    end
    # noop
  end

  def deliver_messages
    # noop
  end
end