# frozen_string_literal: true

require 'i18n'

begin
  require 'trx_ext'
rescue LoadError
end

module Yes
  module Core
    module ReadModel
      # Base class for read model builders that distribute events to proper event handlers
      # and manage read model lifecycle including rebuilding.
      class Builder
        include OpenTelemetry::Trackable

        EventValidationErrorsPresent = Class.new(Error)
        InvalidReadModelBuilderClass = Class.new(Error)
        MissingReadModelId = Class.new(Error)
        RebuildError = Class.new(Error)

        READ_MODEL_CLASS_REGEXP =
          /(?<context>\w+)::ReadModels::(?<version>V\d+)?(::)?(?<aggregate>\w+)/.freeze

        # Based on event type class it distributes event to a proper event handler
        # @param event [Yes::Core::Event]
        # @param read_model [ActiveRecord::Base] AR object
        # @return [void]
        def call(event, read_model: nil)
          read_model ||= read_model(event)

          otl_record_data(read_model, event)

          handler = handler_class(event)&.new(read_model)
          return unless handler

          locale = event.data['locale']&.to_sym || I18n.default_locale
          return unless correct_locale?(locale)

          I18n.with_locale(locale) do
            next handler.call(event) unless self.class.otl_tracer

            OpenTelemetry::OtlSpan.new(otl_data: otl_data(handler), otl_tracer: self.class.otl_tracer).otl_span do
              handler.call(event)
            end
          ensure
            otl_record_processed(read_model, event, handler)
          end
        end
        otl_trackable :call, OpenTelemetry::OtlSpan::OtlData.new(
          span_kind: :consumer,
          links_extractor: ->(event, **) { event.metadata['otl_contexts'] },
          track_sql: true
        )

        # @param eventstore [PgEventstore::Client] eventstore client
        # @param ids [Array<String>] ids to rebuild
        def rebuild_many(
          eventstore: PgEventstore.client,
          ids: read_model_class.pluck(:id)
        )
          ids.each { |id| rebuild(eventstore:, id:) }
        end

        # @param id [String] id of the read model to rebuild
        # @param eventstore [PgEventstore::Client] eventstore client
        # @return [ActiveRecord::Base, nil]
        # @raise [Yes::Core::ReadModel::Builder::RebuildError]
        def rebuild(id:, eventstore: PgEventstore.client)
          # delete is intentional to avoid any callbacks
          read_model_class.delete(id) if read_model_class.exists?(id)
          context = read_model_class_name_match[:context]
          stream_name = read_model_class_name_match[:aggregate]
          enum = eventstore.read_paginated(
            PgEventstore::Stream.new(context:, stream_name:, stream_id: id), options: { resolve_link_tos: true }
          )
          read_model = read_model_class.find_or_create_by(id:)

          enum.each do |events|
            events.each do |event|
              # pass in read model for efficiency
              call(event, read_model:)
            end
          end
          read_model
        end

        # @return [String]
        def aggregate_id_key
          "#{underscore(read_model_class_name_match[:aggregate].to_s)}_id"
        end

        def initialize
          self.read_model_class = default_read_model_class
        end

        protected

        attr_accessor :read_model_class

        # @param event [Yes::Core::Event] event to find handler for
        # @return [Class, nil] handler class for the event
        def handler_class(event)
          handler_classes = possible_handler_class_names(event)
          handler_instance = handler_classes.lazy.filter_map do |class_name|
            Kernel.const_get(class_name)
          rescue NameError
            next
          end.first

          notify_missing_event_handler(event, handler_classes) unless handler_instance

          handler_instance
        end

        # @param event [Yes::Core::Event] event to find handler names for
        # @return [Array<String>] possible handler class names
        def possible_handler_class_names(event)
          parent_modules = parent_modules_string
          event_type = event_type_name(event)
          event_context = event_context_name(event)
          # in case event has no context
          return ["#{parent_modules}::On#{event_type}"] if event_type == event_context

          [
            "#{parent_modules}::#{event_context}::On#{event_type}",
            "#{parent_modules}::On#{event_type}"
          ]
        end

        # @param event [Yes::Core::Event] event that has no handler
        # @param possible_handler_classes_name [Array<String>] handler class names that were tried
        def notify_missing_event_handler(event, possible_handler_classes_name)
          msg = "The event handler #{possible_handler_classes_name} is not defined."
          Utils::ErrorNotifier.new.event_handler_not_defined(msg, event)
        end

        # @param event [Yes::Core::Event] event to extract type name from
        # @return [String]
        def event_type_name(event)
          event.type.split('::').last
        end

        # @param event [Yes::Core::Event] event to extract context name from
        # @return [String]
        def event_context_name(event)
          event.type.split('::').first
        end

        # @return [String]
        def parent_modules_string
          self.class.to_s.split('::')[0..-2].join('::')
        end

        # @return [Class] default read model class inferred from builder class name
        # @raise [InvalidReadModelBuilderClass] if class name doesn't match expected pattern
        def default_read_model_class
          match = read_model_class_name_match
          klass = [match[:version], match[:aggregate]].compact.join('::')
          Kernel.const_get klass
        rescue NameError, TypeError
          msg = "The Read Model Builder Class #{self.class} does not match modules structure"
          raise InvalidReadModelBuilderClass, msg
        end

        private

        # @return [MatchData] match data from class name regex
        def read_model_class_name_match
          @read_model_class_name_match ||=
            READ_MODEL_CLASS_REGEXP.match(self.class.to_s)
        end

        # @param locale [Symbol] locale to check
        # @return [Boolean] true if locale is available
        def correct_locale?(locale)
          return true unless locale

          I18n.available_locales.map(&:to_sym).include?(locale.to_sym)
        end

        # @param event [Yes::Core::Event] event to find read model for
        # @return [ActiveRecord::Base] the read model instance
        # @raise [MissingReadModelId] if event data doesn't contain aggregate id
        def read_model(event)
          read_model_id = event.data[aggregate_id_key]
          raise MissingReadModelId.new(extra: event) unless read_model_id

          find_or_create_read_model(read_model_id)
        end

        if defined?(TrxExt)
          def find_or_create_read_model(read_model_id)
            read_model_class.trx do
              read_model_class.find_by(id: read_model_id) || read_model_class.create(id: read_model_id)
            end
          end
        else
          def find_or_create_read_model(read_model_id)
            read_model_class.create_or_find_by!(id: read_model_id)
          end
        end

        # derived from https://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-underscore
        # @param word [String] word to underscore
        # @return [String] underscored word
        def underscore(word)
          w = word.dup
          w.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          w.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          w.tr!('-', '_')
          w.downcase
        end

        # @param read_model [ActiveRecord::Base] the read model
        # @param event [Yes::Core::Event] the event
        # @param handler [Yes::Core::ReadModel::EventHandler] the handler that processed the event
        def otl_record_processed(read_model, event, handler)
          return unless ENV['STATSD_ADDR'].present?

          StatsD.increment(
            'events_processing_total',
            tags: {
              type: 'consumer',
              service: Rails.application.class.module_parent.name,
              source: "#{event.metadata.dig('otl_contexts', 'root', 'service') || 'unknown'}-#{event.type}",
              target: "#{Rails.application.class.module_parent.name}-#{self.class.name}",
              read_model_builder_name: self.class.name,
              event_handler_name: handler.class.name,
              event: event.type
            }
          )
        end

        # @param read_model [ActiveRecord::Base] the read model
        # @param event [Yes::Core::Event] the event
        def otl_record_data(read_model, event)
          return unless self.class.otl_tracer
          return if event.created_at.blank?

          span_time = (Time.at(0, self.class.current_span.start_timestamp, :nanosecond).to_f * 1000).to_i
          event_publish_delay_ms = span_time - (event.created_at.utc.to_f * 1000).to_i

          self.class.current_span&.add_attributes(
            {
              'event_published_delay_ms' => event_publish_delay_ms,
              'event_published_at_ms' => (event.created_at.to_f * 1000).to_i,
              'command_request_started_at_ms' => event.metadata.dig('otl_contexts', 'timestamps',
                                                                     'command_request_started_at_ms'),
              'command_handling_started_at_ms' => event.metadata.dig('otl_contexts', 'timestamps',
                                                                     'command_handling_started_at_ms'),
              'read_model_builder.name' => self.class.name,
              'read_model_builder.read_model.class' => read_model.class.name
            }.compact_blank
          )
        end

        # @param handler [Yes::Core::ReadModel::EventHandler] handler to build OTL data for
        # @return [Yes::Core::OpenTelemetry::OtlSpan::OtlData]
        def otl_data(handler)
          OpenTelemetry::OtlSpan::OtlData.new(span_name: handler.class.name, span_kind: :consumer, track_sql: true)
        end
      end
    end
  end
end
