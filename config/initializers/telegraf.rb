require 'socket'

class ::Telegraf
  include Singleton
  attr_accessor :tags, :measurement

  def initialize
    config = Kraken.config.value('telegraf')
    connect if config && config.fetch('enabled', true) != false
    @tags = {}
  end

  def connect
    @socket.flush rescue nil
    @socket.close rescue nil
    config = Kraken.config.value('telegraf')
    @socket = UDPSocket.new Addrinfo.ip(config['host']).afamily
    @socket.connect(Addrinfo.ip(config['host']).ip_address, config['port'].to_i)
  end

  def active?
    !@socket.nil?
  end

  def log(measurement, value, type = nil, tags = {})
    if active?
      value_str = values_for(value, type)
      all_tags = tags.merge(self.tags).map { |k, v| format '%s=%s', escape(k), escape(v) }
      full_name = ([measurement] + all_tags).join(',')
      write format("%s.%s%s\n", self.measurement, full_name, value_str)
    end
  end

  def formatted_value(value)
    case value
    when Float
      format('%2.6f', value)
    else
      value
    end
  end

  TYPE_MAP = {
    time: :ms,
    timing: :ms,
    gauge: :g,
    value: :g,
    count: :c,
    counter: :c,
    histogram: :h,
    ms: :ms,
    g: :g,
    c: :c,
    h: :h,
    s: :s,
    set_item: :s
  }.freeze

  def values_for(value, type)
    case value
    when Hash
      value.map { |k, v| ":#{formatted_value v}|#{TYPE_MAP.fetch(k, :g)}" }.join
    else
      ":#{formatted_value value}|#{TYPE_MAP.fetch(type, :g)}"
    end
  end

  def write(msg)
    tries = 0
    begin
      @socket.write msg
    rescue Errno::ECONNREFUSED
      tries += 1
      if tries == 1
        connect
        retry
      else
        raise
      end
    end
  end

  def escape(str)
    str.to_s.gsub(/[ ,=]/) { |e| "\\#{e}" }
  end

  def count(key, val, tags = {})
    log key, val, :c, tags
  end

  def gauge(key, val, tags = {})
    log key, val, :g, tags
  end

  def histogram(key, val, tags = {})
    log key, val, :h, tags
  end

  def set_item(key, val, tags = {})
    log key, val, :s, tags
  end

  def timing(key, val = nil, tags = {})
    retval = nil
    val = Benchmark.realtime { retval = yield } if block_given?
    log key, val, :ms, tags
    retval
  end

  def increment(key, tags = {})
    count key, 1, tags
  end

  def decrement(key, tags = {})
    count key, -1, tags
  end
end

::Telegraf.instance.measurement = 'kraken'
::Telegraf.instance.tags = { app: 'daemon', environment: Soles.environment.to_s }

Kraken.config.telegraf = Telegraf.instance