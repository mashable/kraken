# Patches koala-3.0.0
# This permits us to specify the max_calls in a batch, so that we can get under
# the payload size limits when 50 calls generates too large a response
require 'koala/api/graph_batch_api'
module Koala
  module Facebook
    class GraphBatchAPI
      def execute(http_options = {})
        return [] if batch_calls.empty?

        max_calls = http_options.delete(:max_calls) || MAX_CALLS
        batch_results = []
        batch_calls.each_slice(max_calls) do |batch|
          # Turn the call args collected into what facebook expects
          args = {"batch" => batch_args(batch)}
          batch.each do |call|
            args.merge!(call.files || {})
          end

          original_api.graph_call("/", args, "post", http_options) do |response|
            raise bad_response if response.nil?

            batch_results += generate_results(response, batch)
          end
        end

        batch_results
      end
    end
  end
end