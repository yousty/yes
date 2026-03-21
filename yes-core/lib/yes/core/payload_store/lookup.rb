# frozen_string_literal: true

module Yes
  module Core
    module PayloadStore
      # Resolves payload store references in events by looking up stored values.
      class Lookup < Base
        # @param event [PgEventstore::Event] the event with potential payload store references
        # @return [Hash] resolved key-value pairs from the payload store
        def call(event)
          return {} unless event.respond_to?(:ps_fields_with_values)

          keys = event.ps_fields_with_values
          return {} if !keys || keys.empty?

          raise Yes::Core::PayloadStore::Errors::MissingClient unless payload_store_client

          ps_response = payload_store_client.get_payloads(keys.values)

          unless ps_response.success?
            handle_payload_store_error(ps_response, event)
            return {}
          end

          resolved_payloads(ps_response, keys)
        end

        private

        # @param response [Object] the successful payload store response
        # @param keys [Hash] the original key mappings
        # @return [Hash] resolved payloads mapped back to their original keys
        def resolved_payloads(response, keys)
          response.value!.each_with_object({}) do |resp, ps_attr_hash|
            key = keys.key(resp.attributes[:key])
            next unless key

            ps_attr_hash[key] = resp.attributes[:value]
          end
        end
      end
    end
  end
end
