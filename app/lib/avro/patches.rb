module Avro::IO
  class AvroTypeErrorWithFieldName < StandardError; end
  class DatumWriter
    def write_record(writers_schema, datum, encoder)
      writers_schema.fields.each do |field|
        begin
          write_data(field.type, datum[field.name], encoder)
        rescue Avro::IO::AvroTypeError
          raise Avro::IO::AvroTypeError.new(field.inspect, datum[field.name])
        end
      end
    end
  end
end
