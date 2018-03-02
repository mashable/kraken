Avro::Builder.add_load_path File.join(Soles.root, 'app', 'schemas')

Avromatic.configure do |c|
  c.schema_store = Avro::InlineSchemaStore.new path: File.join(Soles.root, 'app', 'schemas')
  c.logger = Soles.logger
  unless Kraken.standalone?
    c.registry_url = configuration.value('kafka.registry_url')
    c.build_messaging!
  end
end

configuration.encoder = Avro::Encoder.new

require_relative "../../app/lib/avro/schema_dsl"
require_relative "../../app/lib/avro/patches"