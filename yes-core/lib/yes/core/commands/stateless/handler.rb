# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Stateless
        # Handles stateless commands by publishing events to the event store
        # without maintaining aggregate state in memory.
        #
        # @example
        #   class MyHandler < Yes::Core::Commands::Stateless::Handler
        #     self.event_name = 'Created'
        #   end
        class Handler
          include OpenTelemetry::Trackable
          include HandlerHelpers

          class TransitionError < Error; end
          class InvalidTransition < TransitionError; end
          class NoChangeTransition < TransitionError; end

          MISSING_CMDS_MSG = 'Commands missing'

          module RevisionsLoader
            attr_reader(:revisions, :subject_stream_revision)

            def call
              transaction.otl_contexts.timestamps[:command_handling_started_at_ms] = (Time.now.utc.to_f * 1000).to_i if transaction&.otl_contexts

              if revision_check
                @subject_stream_revision = expected_revision(stream) || :no_stream
                @revisions = load_stream_revisions
              end

              # Here the business logic is checked
              super
            end

            private

            # @return [Hash] { <#PgEventstore::Stream> => expected_revision, ... }
            def load_stream_revisions
              revisions = {}

              self.class.streams&.each do |stream_attrs|
                parts = stream_attrs[:prefix].split('::')
                stream = PgEventstore::Stream.new(
                  context: parts[0],
                  stream_name: parts[1..].join('::'),
                  stream_id: event_payload[stream_attrs[:subject_key]]
                )
                revisions[stream] = expected_revision(stream)
              end

              revisions
            end
          end

          def self.inherited(base)
            super

            base.prepend(RevisionsLoader)
          end

          class << self
            attr_accessor :event_name, :streams

            # @return [Boolean]
            def stateless?
              true
            end
          end

          attr_reader(:events_cache, :cmd_helper, :cmd, :revision_check, :publish_events)
          private :events_cache, :cmd_helper, :cmd

          delegate :origin, :batch_id, :transaction, to: :cmd
          delegate :subject_id, :context, :subject, :locale, :event_payload, to: :cmd_helper
          alias attributes event_payload

          # @param cmd [Yes::Core::Command]
          # @param events_cache [Hash] already cached events { stream => { event_name => event_data } }
          # @param revision_check [Boolean] whether to check stream revisions before publishing
          # @param publish_events [Boolean] whether to actually publish events
          # @return [Stateless::Handler]
          def initialize(cmd, events_cache: {}, revision_check: true, publish_events: true)
            @cmd = cmd
            @cmd_helper = Commands::Helper.new(cmd)
            @revision_check = revision_check
            @publish_events = publish_events
            @events_cache = events_cache
          end

          # @return [void]
          def call
            return unless publish_events

            publish_event(self.class.event_name)
          end

          # Publishes a single event to the event store
          #
          # @param event_name [String] the name of the event to publish
          # @return [PgEventstore::Event] the published event
          def publish_event(event_name)
            transaction.otl_contexts.publisher = self.class.propagate_context(service_name: true) if transaction&.otl_contexts

            type = event_type(event_name)
            event_class = events_module.const_get(event_name)
            event = event_class.new(
              type:,
              data: event_payload,
              metadata: event_metadata
            )
            otl_record_event_data(event)
            verify_revisions! if revision_check

            PgEventstore.client.append_to_stream(
              stream,
              event,
              options: { expected_revision: subject_stream_revision }
            ).tap { otl_record_response(_1) }
          end
          otl_trackable :publish_event, OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Publish Event', span_kind: :producer)

          private

          # @return [Module]
          def events_module
            "#{context}::#{subject}::Events".constantize
          end

          # @param event_name [String]
          # @return [String]
          def event_type(event_name)
            "#{context}::#{stream_name(subject)}#{event_name}"
          end

          # @return [PgEventstore::Stream]
          def stream
            PgEventstore::Stream.new(context:, stream_name: stream_name(subject), stream_id: subject_id)
          end

          # @param subject [String]
          # @return [String]
          def stream_name(subject)
            return subject unless cmd.metadata&.dig(:edit_template_command)

            "#{subject}EditTemplate"
          end

          # @param stream [PgEventstore::Stream]
          # @return [Integer, nil]
          def expected_revision(stream = self.stream)
            PgEventstore.client.read(
              stream,
              options: { direction: 'Backwards', max_count: 1 },
              middlewares: []
            ).first&.stream_revision || 0
          rescue PgEventstore::StreamNotFoundError
            nil
          end

          # @return [Hash]
          def event_metadata
            metadata = { origin:, batch_id: }
            metadata.merge!(cmd.metadata || {})
            metadata.merge!(transaction.for_eventstore_metadata) if transaction
            metadata.deep_transform_keys(&:to_s)
          end

          # @param message [String]
          # @param extra [Hash]
          # @return [InvalidTransition]
          def invalid_transition(message, extra: {})
            raise InvalidTransition.new(extra:), message.to_s
          end

          # @param message [String]
          # @param extra [Hash]
          # @return [NoChangeTransition]
          def no_change_transition(message, extra: {})
            raise NoChangeTransition.new(extra:), message.to_s
          end

          # @return [void]
          # @raise [PgEventstore::WrongExpectedRevisionError]
          def verify_revisions!
            revisions.each do |stream, revision|
              expected = expected_revision(stream)
              next if revision == expected

              revision_error!(revision || -1, expected || -1, stream)
            end
          end

          # @param revision [Integer]
          # @param expected_revision [Integer]
          # @param stream [PgEventstore::Stream]
          def revision_error!(revision, expected_revision, stream)
            PgEventstore::WrongExpectedRevisionError.new(revision:, expected_revision:, stream:).tap do |error|
              self.class.current_span&.status = ::OpenTelemetry::Trace::Status.error('Wrong expected revision')
              self.class.current_span&.add_attributes(
                {
                  current_revision: revision,
                  expected_revision: expected_revision,
                  stream: stream.to_json
                }.stringify_keys
              )

              raise error
            end
          end

          # @param context [String]
          # @param subject [String]
          # @param subject_id [String]
          # @param stream_prefix [String, nil]
          # @return [Yes::Core::Commands::Stateless::Subject]
          def subject_data(
            context: self.class.to_s.split('::')[0],
            subject: self.class.to_s.split('::')[1],
            subject_id: self.subject_id,
            stream_prefix: nil
          )
            Yes::Core::Commands::Stateless::Subject.new(context:, subject:, stream_prefix:, subject_id:)
          end

          # @param command [String]
          # @param context [String]
          # @param subject [String]
          # @return [Data]
          def command_data(
            command:,
            context: self.class.to_s.split('::')[0],
            subject: self.class.to_s.split('::')[1]
          )
            Data.define(:context, :subject, :command).new(context:, subject:, command:)
          end

          # @return [Yes::Core::Stateless::MissingCommandsAggregator]
          def result_aggregator
            @result_aggregator ||= Yes::Core::Stateless::MissingCommandsAggregator.new
          end

          # @param event [PgEventstore::Event]
          # @return [void]
          def otl_record_event_data(event)
            self.class.current_span&.add_attributes(
              {
                'event.type' => event.type,
                'event.data' => event.data.to_json,
                'event.metadata' => event.metadata.to_json
              }
            )
          end

          # @param result [PgEventstore::Event]
          # @return [void]
          def otl_record_response(result)
            StatsD.increment(
              'events_processing_total',
              tags: {
                service: Rails.application.class.module_parent.name,
                source: "#{Rails.application.class.module_parent.name}-#{result.type}",
                target: "#{Rails.application.class.module_parent.name}-#{result.type}",
                type: 'producer',
                event: result.type
              }
            ) if ENV['STATSD_ADDR'].present?

            self.class.current_span&.status = ::OpenTelemetry::Trace::Status.ok
            self.class.current_span&.add_event(
              'Event Published to PgEventstore',
              timestamp: result.created_at,
              attributes: {
                'event.type' => result.type,
                'event.link_id' => result.link_id || '',
                'global_position' => result.global_position,
                'stream' => result.stream.to_json,
                'stream.revision' => result.stream_revision,
                'timestamp_ms' => (result.created_at.to_f * 1000).to_i
              }
            )
          end
        end
      end
    end
  end
end
