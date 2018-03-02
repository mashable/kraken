class Avro::Encoder
  def initialize
  end

  def encode(model, options)
    model[:_timestamp] = Time.now
    model = model.deep_stringify_keys
    if Kraken.standalone?
      s = Avromatic.schema_store.find(options[:schema_name])
      Avro::SchemaValidator.validate!(s, model)
      return [options[:schema_name], model].to_json
    else
      Avromatic.messaging.encode model.deep_stringify_keys, options
    end
  end

  def decode(payload)
    if Kraken.standalone?
      schema, model = JSON.parse payload
      s = Avromatic.schema_store.find(schema)
      Avro::SchemaValidator.validate!(s, model)
      model
    else
      Avromatic.messaging.decode payload
    end
  end
end