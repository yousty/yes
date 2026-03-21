# frozen_string_literal: true

module Yes
  module Core
    module OpenTelemetry
      # Mixin for adding OpenTelemetry tracing to classes.
      #
      # When OpenTelemetry is not configured (no tracer set), all tracing
      # operations are no-ops with zero overhead.
      #
      # @example
      #   class MyService
      #     include Yes::Core::OpenTelemetry::Trackable
      #
      #     def process(data)
      #       # implementation
      #     end
      #     otl_trackable :process, OtlSpan::OtlData.new(span_name: 'Process Data')
      #   end
      module Trackable
        extend ActiveSupport::Concern

        module ClassMethods
          # Decorates a method with OpenTelemetry tracing.
          #
          # @param method_name [Symbol] the method to track
          # @param otl_data [OtlSpan::OtlData] span configuration
          # @return [Symbol] the tracked method name
          def otl_trackable(method_name, otl_data = OtlSpan::OtlData.new(span_name: nil))
            otl_data.span_name ||= name

            instance_module = Module.new do
              define_method(method_name) do |*args, **kwargs, &blk|
                return super(*args, **kwargs, &blk) unless singleton_class.otl_tracer

                OtlSpan.new(otl_data:, otl_tracer: singleton_class.otl_tracer).otl_span(*args, **kwargs) do
                  super(*args, **kwargs, &blk)
                end
              end
            end
            prepend instance_module

            method_name
          end

          # @return [Object, nil] the configured OpenTelemetry tracer or nil
          def otl_tracer
            Yes::Core.configuration.otl_tracer
          end

          # @return [OpenTelemetry::Trace::Span, nil] the current span or nil if no tracer
          def current_span
            return nil unless otl_tracer

            ::OpenTelemetry::Trace.current_span
          end

          # @return [OpenTelemetry::Context, nil] the current context or nil if no tracer
          def current_context
            return nil unless otl_tracer

            ::OpenTelemetry::Context.current
          end

          # Executes a block within a new span.
          #
          # @param name [String] the span name
          # @yield the block to execute
          # @return [Object] the return value of the block
          def with_otl_span(name, &)
            return yield unless otl_tracer

            otl_tracer.in_span(name, &)
          end

          # Propagates the current context to a carrier hash.
          #
          # @param ctx_carrier [Hash] the carrier to inject context into
          # @param service_name [Boolean] whether to include the service name
          # @return [HashWithIndifferentAccess] the carrier with context
          def propagate_context(ctx_carrier = {}, service_name: false)
            ctx_carrier.tap do |carrier|
              ::OpenTelemetry.propagation.inject(carrier)
              ctx_carrier[:service] = Rails.application.class.module_parent.name if service_name
            end.with_indifferent_access
          end

          # Extracts context from a carrier hash.
          #
          # @param carrier [Hash, nil] the carrier to extract from
          # @return [OpenTelemetry::Context, nil] the extracted context
          def extract_current_context(carrier)
            return nil unless carrier&.key?('traceparent')

            ::OpenTelemetry.propagation.extract(carrier)
          end
        end
      end
    end
  end
end
