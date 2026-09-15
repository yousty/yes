# frozen_string_literal: true

module Yes
  module Core
    module OpenTelemetry
      # Wraps OpenTelemetry span creation with SQL tracking support.
      #
      # @example
      #   span = OtlSpan.new(otl_data: OtlData.new(span_name: 'MySpan'), otl_tracer: tracer)
      #   span.otl_span(arg1, arg2) { do_work }
      class OtlSpan
        # Span attribute that names the tolerated error a span ended with (see {OtlData#tolerated_errors}).
        OUTCOME_ATTRIBUTE = 'outcome'

        # Span attribute with the number of retries a command needed before it settled.
        RETRIES_ATTRIBUTE = 'retries'

        # A revision conflict is an optimistic-concurrency retry signal, not a failure: the
        # command is re-run and almost always succeeds. Publishing spans tolerate it so the
        # span status stays clean and the conflict is countable on its own.
        REVISION_CONFLICT = { PgEventstore::WrongExpectedRevisionError => 'revision_conflict' }.freeze

        # Configuration struct for OpenTelemetry span data
        OtlData = Struct.new(:span_name, :span_kind, :span_attributes, :links_extractor, :track_sql,
                             :tolerated_errors) do
          # @param span_name [String, nil] name of the span
          # @param span_kind [Symbol] kind of span (:internal, :client, :server, :producer, :consumer)
          # @param span_attributes [Hash] additional span attributes
          # @param links_extractor [Proc] extracts OTL context links from arguments
          # @param track_sql [Boolean] whether to track SQL queries within the span
          # @param tolerated_errors [Hash{Class => String}] errors that are re-raised but do not mark the
          #   span as failed; the span gets the mapped value as its +outcome+ attribute instead
          def initialize(span_name: nil, span_kind: :internal, span_attributes: {}, links_extractor: proc { [] },
                         track_sql: false, tolerated_errors: {})
            super
          end
        end

        # @return [OtlData] span configuration
        attr_reader :otl_data

        # @return [Object] OpenTelemetry tracer instance
        attr_reader :otl_tracer

        # Stamps the number of retries a command needed on the span it is running in, so
        # contention shows up per command and not only per publish attempt.
        #
        # @param retries [Integer] retries performed before the command settled
        # @return [void]
        def self.record_retries(retries)
          return if retries.zero? || Yes::Core.configuration.otl_tracer.nil?

          ::OpenTelemetry::Trace.current_span.set_attribute(RETRIES_ATTRIBUTE, retries)
        end

        # @param otl_data [OtlData] span configuration
        # @param otl_tracer [Object] OpenTelemetry tracer instance
        def initialize(otl_data:, otl_tracer:)
          @otl_data = otl_data
          @otl_tracer = otl_tracer
        end

        # Creates a span and executes the given block within it.
        #
        # A tolerated error (see {OtlData#tolerated_errors}) is recorded on the span as an exception
        # event and as the +outcome+ attribute, but the span keeps a non-error status. The error is
        # re-raised once the span has ended, so callers see exactly the same exception as before.
        #
        # @param args [Array] positional arguments passed to the links extractor
        # @param kwargs [Hash] keyword arguments passed to the links extractor
        # @yield the block to execute within the span
        # @return [Object] the return value of the block
        def otl_span(*args, **kwargs, &)
          parent_span = current_parent_span
          root_track_sql = root_track_sql?(parent_span)
          tolerated_error = nil

          result = otl_tracer.in_span(
            otl_data.span_name || 'UnknownName',
            links: otl_links(args, kwargs),
            kind: otl_data.span_kind,
            attributes: span_attributes(root_track_sql)
          ) do |span|
            run_block(parent_span, root_track_sql, &)
          rescue StandardError => e
            tolerated_error = tolerate(span, e)
            nil
          end

          raise tolerated_error if tolerated_error

          result
        end

        private

        # @return [::OpenTelemetry::Trace::Span, nil] the span this one is created under, if any
        def current_parent_span
          span = ::OpenTelemetry::Trace.current_span
          span.context.valid? ? span : nil
        end

        # @param parent_span [::OpenTelemetry::Trace::Span, nil] the enclosing span, if any
        # @return [Boolean, nil] whether an enclosing span already tracks SQL
        def root_track_sql?(parent_span)
          parent_span&.try(:attributes)&.[]('root_track_sql') || parent_span&.try(:attributes)&.[]('track_sql')
        end

        # @param root_track_sql [Boolean, nil] whether an enclosing span already tracks SQL
        # @return [Hash] the attributes the span starts with
        def span_attributes(root_track_sql)
          {
            'track_sql' => otl_data.track_sql,
            'root_track_sql' => root_track_sql || false
          }.merge(otl_data.span_attributes)
        end

        # Runs the traced block, wrapping it in SQL tracking when the span asks for it.
        #
        # @param parent_span [OpenTelemetry::Trace::Span, nil] the enclosing span, if any
        # @param root_track_sql [Boolean, nil] whether an enclosing span already tracks SQL
        # @yield the block to execute
        # @return [Object, nil] the return value of the block
        def run_block(parent_span, root_track_sql, &)
          return unless block_given?
          return yield if !root_track_sql && !otl_data.track_sql
          return yield if parent_span.present? && root_track_sql

          ActiveSupport::Notifications.subscribed(sql_span_callback, 'sql.active_record', &)
        end

        # @return [Proc] records one child span per SQL statement executed inside the traced block
        def sql_span_callback
          lambda do |sql_event|
            next if %w[SCHEMA TRANSACTION].include?(sql_event.payload[:name])

            record_sql_span(sql_event.payload)
          end
        end

        # @param payload [Hash] the +sql.active_record+ notification payload
        # @return [void]
        def record_sql_span(payload)
          otl_tracer.in_span("SQL #{payload[:name]}") do |span|
            span.set_attribute('db.system', 'postgresql')
            span.set_attribute('db.statement', payload[:sql])
            span.set_attribute('db.binds', sql_binds(payload[:binds]))
            span.set_attribute('db.event_name', payload[:name])
          end
        end

        # @param binds [Array] the statement's bind parameters
        # @return [String] the binds as JSON, one +name+/+value+ pair each
        def sql_binds(binds)
          binds.map do |attr|
            next { name: attr.name, value: attr.value } if attr.respond_to?(:name) && attr.respond_to?(:value)

            { name: attr.class.to_s, value: attr }
          end.to_json
        end

        # Records a tolerated error on the span without failing it.
        #
        # @param span [OpenTelemetry::Trace::Span] the span the error was raised in
        # @param error [StandardError] the error raised by the traced block
        # @return [StandardError] the error, to be re-raised once the span has ended
        # @raise [StandardError] the error itself when it is not tolerated
        def tolerate(span, error)
          outcome = otl_data.tolerated_errors.find { |klass, _outcome| error.is_a?(klass) }&.last
          raise error unless outcome

          span.record_exception(error)
          span.set_attribute(OUTCOME_ATTRIBUTE, outcome)
          error
        end

        # Extracts OpenTelemetry links from arguments using the configured links_extractor.
        #
        # @param args [Array] positional arguments
        # @param kwargs [Hash] keyword arguments
        # @return [Array<OpenTelemetry::Trace::Link>] extracted links
        def otl_links(args, kwargs)
          return [] if args.blank? && kwargs.blank?
          return [] unless (otl_contexts = otl_data.links_extractor.call(*args, **kwargs).presence)

          otl_contexts.filter_map do |_context_name, context_data|
            next unless context_data['traceparent']

            trace_parent_ctx = ::OpenTelemetry::Trace::Propagation::TraceContext::TraceParent.from_string(
              context_data['traceparent']
            )
            trace_span_ctx = ::OpenTelemetry::Trace::SpanContext.new(
              trace_id: trace_parent_ctx.trace_id,
              span_id: trace_parent_ctx.span_id,
              trace_flags: trace_parent_ctx.flags
            )
            ::OpenTelemetry::Trace::Link.new(trace_span_ctx)
          end
        end
      end
    end
  end
end
