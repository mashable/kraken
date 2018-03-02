module Avro::SchemaDSL
  extend ActiveSupport::Concern

  module ClassMethods
    def namespace(name, &block)
      @active_namespace = name
      yield
      @active_namespace = nil
    end

    def schema(name = nil, &block)
      if block_given?
        ns = @active_namespace && @active_namespace.to_s
        schema = Avro::Builder.build_schema do
          namespace ns if ns.present?
          record name do
            instance_exec(&block)
            required :_timestamp, :timestamp
          end
        end
        Avromatic.schema_store.store name.to_s, @active_namespace.to_s, schema
      else
        Avromatic.schema_store.find name
      end
    end
  end
end