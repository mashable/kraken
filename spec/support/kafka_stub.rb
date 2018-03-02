class FakeKafkaProducer
  def initialize(real)
    @messages = {}
    @real = real
    @stub = true
  end

  def unstub
    @stub = false
    yield
    @stub = true
  end

  def produce(message, options = {})
    topic = options[:topic]
    self.channel(topic) << message
    @real.produce(message, options) if not @stub
  end

  def decode(message)
    Kraken.config.encoder.decode message
  end

  def channel(channel)
    channel = "kraken.#{channel}" unless channel.start_with? "kraken."
    @messages[channel] ||= []
  end

  def first_message(channel)
    message(channel, 0)
  end

  def message(channel, index)
    msg = self.channel(channel)[index]
    return nil if msg.nil?
    m = decode(msg).with_indifferent_access
    m.delete :_timestamp
    m
  end

  def deliver_messages
  end
end

RSpec.shared_context "kafka stub", type: :worker do
  let(:kafka) { FakeKafkaProducer.new Kraken.config.kafka_producer }
  before(:each) do |example|
    allow(Kraken.config).to receive(:kafka_producer).and_return(kafka)
  end
end
