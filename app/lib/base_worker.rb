class BaseWorker
  include Avro::SchemaDSL
  include ::Sidekiq::Worker

  def perform(payload)
    raise 'Unimplemented'
  end

  def kafka
    Kraken.config.kafka_producer
  end

  def with_redis
    Kraken.config.redis.with {|r| yield r }
  end

  def emit(topic, model, options = {})
    Bugsnag.before_notify_callbacks << ->(notif) { notif.add_tab(:payload, {topic: topic, model: model, options: options}) }
    begin
      payload = Kraken.config.encoder.encode(
        model.deep_stringify_keys,
        schema_name: options[:schema],
        subject: "kraken.#{topic}-value"
      )

      topic = "kraken.#{topic}" unless topic.start_with? "kraken."
      kafka.produce(payload, topic: topic)
    ensure
      Bugsnag.before_notify_callbacks.pop
    end
  end

  def get(url, options = {})
    http_method :get, url, options
  end

  def post(url, options = {})
    http_method :post, url, options
  end

  def http_method(method, url, options = {})
    conn(url).send(method, url, options) do |req|
      req.headers = { 'User-Agent' => Kraken.config.value("kraken.user_agent") }
      yield req if block_given?
    end
  end

  def conn(url)
    Faraday.new(url) do |faraday|
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
      yield faraday if block_given?
    end
  end

  def with_last_state(key, default = 0)
    key = "kraken.state:#{Soles.environment}:#{self.class.to_s}:states:#{key}"
    state_var = redis.get(key) || 0
    res = yield state_var, ->(val) { redis.set(key, res) }
  end

  # Check if we've seen a given value in an arbitrary set recently
  # Used to keep a short-term transient memory of the keys that we've recently
  # processed.
  def recent_member?(key, member)
    key = member_set_key(key)
    with_redis do |redis|
      !redis.zscore(key, member).nil?
    end
  end

  def member_set_key(key)
    "kraken.state:#{Soles.environment}:#{self.class.to_s}:sets:#{key}"
  end

  def set_membership_ttl!(key, ttl)
    with_redis do |redis|
      key = member_set_key(key)
      if redis.ttl(key) == -1
        redis.expire key, ttl.to_i
      end
    end
  end

  # Record an arbitrary value for time-recent set membership. This is used
  # to keep system-wide state indicating that we've seen a certain value recently
  # which will generally be used to avoid re-emitting a duplicate record
  def keep_member!(key, member, max_members)
    key = "kraken.state:#{Soles.environment}:#{self.class.to_s}:sets:#{key}"
    with_redis do |redis|
      redis.zadd key, (Time.now.to_f * 1000).to_i, member
      redis.zremrangebyrank key, 0, (max_members.abs + 1) * -1
    end
  end

  def add_member(key, member, max = 3000)
    if recent_member?(key, member)
      false
    else
      keep_member! key, member, max
      true
    end
  end

  def bloom_filter(name, size = 10_000_000, error_rate = 1.0e-6)
    key = "bloom_filter:#{name}"
    @bloom_filters ||= {}
    @bloom_filters[key] ||= begin
      Kraken.config.redis.with do |r|
        Redis::Bloomfilter.new({
          redis: r,
          key_name: key,
          error_rate: error_rate,
          size: size,
          driver: "lua"
        })
      end
    end
  end

  def self.produce(options, &block)
    options[:block] = block
    @production_options = options
  end

  def self.production_options
    @production_options
  end

  def self.register_connector(name_or_options, topics)
    Kraken.config.topic_registry.register(name_or_options, Array(topics))
  end
end