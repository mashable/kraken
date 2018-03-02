# Kraken
Tutorials, ruby resources, and additional documentation can be found [Here](https://github.com/mashable/kraken/wiki)


## Requirements

* Ruby 2.1+
* Redis 3.0+
* Kafka (Confluent Platform - not needed if running in standalone mode)

## Bootstrapping

* Clone this repo

Bootstrapping automatically:

* Run `rake`

Manually:

* Install Ruby 2.1+ (perhaps via RVM?)
* Run `bundle` (`gem install bundler` first if bundler doesn't exist)
* Run `STANDALONE=1 bin/rspec` to run the test suite
* Run `STANDALONE=1 bin/kraken console` to boot an interactive Kraken console
* Run `STANDALONE=1 bin/kraken help` for documentation on other commands

## Configuration

You can override configuration with a config/local.yml file. It will take precedence over committed configs. For example:

    development:
      zookeeper:
        nodes:
          - 192.168.99.100:32181
      kafka:
        connect: http://192.168.99.100:28082
        registry_url: http://192.168.99.100:8081
        seeds:
          - 192.168.99.100:29092
      redis:
        url: redis://127.0.0.1:6379/1

This is helpful if you are running in non-standalone mode.

## Creating new workers

To create a new worker, you'll simply create a new file under app/workers/. The class name should match the directory structure (ie, `Foo::Bar::MyWorker` should live at `foo/bar/my_worker.rb`.)

The basic format of a worker is:

```ruby
class Foo::Bar::MyWorker < BaseWorker
  # This defines a scheduled task which will be invoked and can be used to create
  # instances of this job
  produce every: 1.week do
    perform_async "some_argument"
  end

  # The "schema" DSL is used to define an Avro schema for this record. It will be enforced
  # during payload emission to Kafka. An exception will be thrown if required fields are missing,
  # or if fields are of the wrong type. Fields specified in the payload that are not included in
  # the schema will be dropped and not passed downstream.
  #
  # Naming convention should be com.mashable.kraken.<namespace>.<worker>
  schema "com.mashable.kraken.foo.bar.my_worker" do
    # [required|optional] :{name}, :{type}
    required :id, :long
    optional :note, :string
  end

  # The `perform` method is the only required method in the worker, and is invoked to
  # perform a unit of work. It will be passed whatever args the job was queued with
  # (usually via perform_async)
  #
  # You can pass arbitrary arguments to the job, as long as the perform() signature can accept
  # them. Arg payloads will be cast to/from JSON.
  def perform(arg)
    # Build a payload. Its structure and data types must conform to the schema we intend to
    # use on emission to Kafka.
    payload = {
      id: 123,
      note: "this is a note: #{arg}"
    }

    # Validates the payload, serializes it, and emits it to the given Kafka topic
    emit "my_worker.topic_name", payload, schema: "com.mashable.kraken.foo.bar.my_worker"
  end
end
```

Additionally, you should write tests for your workers. This allows you to quickly iterate on development, ensures functional correctness, and allows future development to happen more easily. Writing tests is easy. Given a worker `Foo::Bar::MyWorker` you will create a file in `spec/workers/foo/bar/my_worker_spec.rb` similar to the following:

```ruby
require 'soles_helper'

describe Foo::Bar::MyWorker, :vcr do
  it "can run" do
    subject.perform("sample arg")

    # Declare that we expect the test to emit one message
    expect(kafka.channel("my_worker.topic_name").length.to eq 1

    # Test that the message emitted is what we expected.
    expect(kafka.first_message("my_worker.topic_name")).to match(
        "id" => 123,
        "note" => "this is a note: sample arg"
    )
  end
end
```

By default, tests will not emit payloads to Kafka, but payloads are validated against schemas and go through a serialize-deserialize round trip.

You can run your test with `STANDALONE=1 bin/rspec spec/workers/foo/bar/my_worker_spec.rb`, or the full suite with just `STANDALONE=1 bin/rspec`

## Hive DDL schemas

You may need to generate a DDL schema for Athena. This can be accomplished via:

    rake hive:build_schema

If you don't want interactive mode, you can pass arguments:

    rake hive:build_schema -- -t facebook_posts -b mashable-data -p "/development/json/kraken.facebook.posts/" -s "org.apache.hcatalog.data.JsonSerDe" -f kraken.facebook.posts+0+0000001600.json

## Kafka Cluster

Standalone mode will mock out the Kafka and Zookeeper requirements so that you can develop without needing a full cluster up and running. However, if you want to develop against a full cluster, you can easily do so with docker:

    docker run --rm --net=host -e ADV_HOST=192.168.4.139 -e ZK_PORT=32181 -e REGISTRY_PORT=8081 -e REST_PORT=8082 -e CONNECT_PORT=28082 -e BROKER_PORT=29092 -e AWS_ACCESS_KEY_ID="key" -e AWS_SECRET_ACCESS_KEY="secret" landoop/fast-data-dev

See https://github.com/Landoop/fast-data-dev for more complete instructions.

You can always bring up a Kafka cluster manually if you want. The required pieces are:

* A Zookeeper node
* A Kafka broker
* A Kafka schema_registry node (for Avro schema coordination)
* A Kafka REST proxy (for connector management)
* Optionally, a Kafka-Connect (distributed mode) instance, for writing topics to one or more sinks
