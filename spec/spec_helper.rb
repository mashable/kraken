ENV['SOLES_ENV'] = "test"
require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
  add_group "Workers", "app/workers"
  add_group "Models", "app/models"
  add_group "Controllers", "app/controller"
  add_group "Lib", "app/lib"
end

require 'webmock/rspec'

require 'vcr'
require 'timecop'

VCR.configure do |config|
  config.ignore_hosts "127.0.0.1", "192.168.4.139", "192.168.99.101"
  config.cassette_library_dir = "spec/fixtures/vcr"
  config.hook_into :webmock
  config.hook_into :faraday
  # config.debug_logger = $stderr
end

Dir[File.expand_path(File.join(__dir__, 'support', '**', '*.rb'))].each { |f| require f }

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{spec/worker}) do |metadata|
    metadata[:type] = :worker
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.around(:each, :vcr) do |example|
    name = if example.metadata[:cassette]
             example.metadata[:described_class].to_s + " " + example.metadata[:cassette]
           else
             example.metadata[:full_description]
           end
    name = name.split(/\s+/, 2).join("/").underscore.gsub(/[^\w\/]+/, "_")
    options = example.metadata.slice(:record, :match_requests_on).except(:example_group)
    VCR.use_cassette(name, options) { example.call }
  end

  config.after(:each) do
    Kraken.config.kafka_producer.deliver_messages
  end

  config.before(:each) do
    Kraken.config.redis.with(&:flushdb)
  end

  config.around(:each, :freeze_time) do |example|
    ft = example.metadata[:freeze_time]
    t = case ft
    when Integer
      Time.at(ft)
    when String
      Time.parse(ft)
    when Time, Date, DateTime
      ft
    else
      raise "Invalid type: #{ft.type} given for freeze_time"
    end

    Timecop.freeze(t) do
      example.call
    end
  end
end