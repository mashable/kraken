class RedisModel
  class NotFound < StandardError; end

  include Virtus.model
  attribute :id, String

  class << self
    def namespace(ns)
      @namespace = ns
    end

    def find(id)
      Kraken.config.redis.with do |client|
        res = client.get("model:#{@namespace}:#{id}")
        if res
          new JSON.parse(res)
        else
          raise NotFound
        end
      end
    end
  end

  def save
    Kraken.config.redis.with do |client|
      client.set(_key, JSON.dump(self.attributes))
    end
  end

  def destroy
    Kraken.config.redis.with do |client|
      client.del(_key)
    end
  end

  def _key
    self.class._key(self.id)
  end

  def self._key(id)
    "model:#{@namespace}:#{id}"
  end
end