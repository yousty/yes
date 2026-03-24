# frozen_string_literal: true

module Yes
  module Core
    module ReadModel
      # Base class for event handlers that process events and update read models.
      class EventHandler
        include OpenTelemetry::Trackable

        attr_accessor :read_model, :payload_store_lookup
        private :read_model, :payload_store_lookup, :read_model=, :payload_store_lookup=

        # @param read_model [ActiveRecord::Base] AR object
        # @param payload_store_lookup [#call] payload store lookup instance
        def initialize(
          read_model,
          payload_store_lookup: Yes::Core::PayloadStore::Lookup.new
        )
          raise ArgumentError unless read_model

          self.read_model = read_model
          self.payload_store_lookup = payload_store_lookup
        end

        # @param event [Yes::Core::Event] event to handle
        # @return [Yes::Core::Event] the processed event
        def call(event)
          otl_record_event_data(event) if self.class.otl_tracer

          payload_store_lookup.call(event).each do |key, value|
            event.data[key.to_s] = value
          end

          event
        end
        otl_trackable :call, OpenTelemetry::OtlSpan::OtlData.new(span_kind: :consumer, track_sql: true)

        private

        # @param event [Yes::Core::Event] event to record telemetry data for
        def otl_record_event_data(event)
          return if event.created_at.blank?

          span_time = (Time.at(0, self.class.current_span.start_timestamp, :nanosecond).to_f * 1000).to_i
          event_publish_delay_ms = span_time - (event.created_at.utc.to_f * 1000).to_i

          self.class.current_span&.add_attributes(
            {
              'event_published_delay_ms' => event_publish_delay_ms,
              'event_published_at_ms' => (event.created_at.utc.to_f * 1000).to_i,
              'command_request_started_at_ms' => event.metadata.dig('otl_contexts', 'timestamps',
                                                                    'command_request_started_at_ms'),
              'command_handling_started_at_ms' => event.metadata.dig('otl_contexts', 'timestamps',
                                                                     'command_handling_started_at_ms'),
              'event.type' => event.type,
              'event.data' => event.data.to_json,
              'event.metadata' => event.metadata.to_json
            }.compact_blank
          )
        end
      end
    end
  end
end
