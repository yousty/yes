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
        # Configuration struct for OpenTelemetry span data
        OtlData = Struct.new(:span_name, :span_kind, :span_attributes, :links_extractor, :track_sql) do
          # @param span_name [String, nil] name of the span
          # @param span_kind [Symbol] kind of span (:internal, :client, :server, :producer, :consumer)
          # @param span_attributes [Hash] additional span attributes
          # @param links_extractor [Proc] extracts OTL context links from arguments
          # @param track_sql [Boolean] whether to track SQL queries within the span
          def initialize(span_name: nil, span_kind: :internal, span_attributes: {}, links_extractor: proc { [] },
                         track_sql: false)
            super
          end
        end

        # @return [OtlData] span configuration
        attr_reader :otl_data

        # @return [Object] OpenTelemetry tracer instance
        attr_reader :otl_tracer

        # @param otl_data [OtlData] span configuration
        # @param otl_tracer [Object] OpenTelemetry tracer instance
        def initialize(otl_data:, otl_tracer:)
          @otl_data = otl_data
          @otl_tracer = otl_tracer
        end

        # Creates a span and executes the given block within it.
        #
        # @param args [Array] positional arguments passed to the links extractor
        # @param kwargs [Hash] keyword arguments passed to the links extractor
        # @yield the block to execute within the span
        # @return [Object] the return value of the block
        def otl_span(*args, **kwargs, &block)
          links = otl_links(args, kwargs)

          parent_span = ::OpenTelemetry::Trace.current_span.context.valid? ? ::OpenTelemetry::Trace.current_span : nil
          root_track_sql = parent_span&.try(:attributes)&.[]('root_track_sql') ||
                           parent_span&.try(:attributes)&.[]('track_sql')

          otl_tracer.in_span(
            otl_data.span_name || 'UnknownName',
            links:,
            kind: otl_data.span_kind,
            attributes: {
              'track_sql' => otl_data.track_sql,
              'root_track_sql' => root_track_sql || false
            }.merge(otl_data.span_attributes)
          ) do
            next unless block_given?
            next yield if !root_track_sql && !otl_data.track_sql
            next yield if parent_span.present? && root_track_sql

            callback = lambda do |sql_event|
              next if %w[SCHEMA TRANSACTION].include?(sql_event.payload[:name])

              otl_tracer.in_span("SQL #{sql_event.payload[:name]}") do |span|
                span.set_attribute('db.system', 'postgresql')
                span.set_attribute('db.statement', sql_event.payload[:sql])
                span.set_attribute('db.binds', sql_event.payload[:binds].map do |attr|
                  next { name: attr.name, value: attr.value } if attr.respond_to?(:name) && attr.respond_to?(:value)

                  { name: attr.class.to_s, value: attr }
                end.to_json)
                span.set_attribute('db.event_name', sql_event.payload[:name])
              end
            end
            ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
          end
        end

        private

        # Extracts OpenTelemetry links from arguments using the configured links_extractor.
        #
        # @param args [Array] positional arguments
        # @param kwargs [Hash] keyword arguments
        # @return [Array<OpenTelemetry::Trace::Link>] extracted links
        def otl_links(args, kwargs)
          return [] if args.blank? && kwargs.blank?
          return [] unless (otl_contexts = otl_data.links_extractor.call(*args, **kwargs).presence)

          otl_contexts.map do |_context_name, context_data|
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
          end.compact
        end
      end
    end
  end
end
