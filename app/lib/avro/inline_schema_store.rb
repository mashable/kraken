class Avro::InlineSchemaStore < AvroTurf::SchemaStore
  def initialize(options = {})
    super
    @mutex = Mutex.new
  end

  def find(name, namespace = nil)
    @mutex.synchronize {
      fullname = Avro::Name.make_fullname(name, namespace)
      @schemas[fullname] || super
    }
  end

  def store(name, namespace, schema)
    @mutex.synchronize {
      fullname = Avro::Name.make_fullname(name, namespace)
      @schemas[fullname] = schema
    }
  end
end