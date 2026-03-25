# frozen_string_literal: true

require 'net/http'

module Yes
  module Core
    # Manages PgEventstore subscriptions with optional heartbeat and OpenTelemetry tracing.
    #
    # @example
    #   subscriptions = Yes::Core::Subscriptions.new
    #   subscriptions.subscribe_to_all(handler, filter_opts)
    #   subscriptions.start
    class Subscriptions
      include Yes::Core::OpenTelemetry::Trackable

      # @return [Integer] Timeout in seconds for subscriptions to start
      SUBSCRIPTIONS_START_TIMEOUT = 20

      # @return [PgEventstore::SubscriptionsManager] the subscriptions manager
      attr_reader :subscriptions_manager

      # @return [PgEventstore::Client] the event store client
      attr_reader :client

      # Initializes subscriptions with the given PgEventstore config.
      #
      # @param config_name [Symbol] the PgEventstore configuration name
      def initialize(config_name: :default)
        @subscriptions_manager = PgEventstore.subscriptions_manager(
          config_name,
          subscription_set: Rails.application.class.name.split('::').first
        )
        @client = PgEventstore.client(config_name)
      end

      # Subscribes a handler to all events matching the given filter.
      #
      # @param handler [#call] the event handler
      # @param filter_opts [Hash] PgEventstore filter options
      # @param subscription_opts [Hash] additional subscription options
      # @return [void]
      def subscribe_to_all(handler, filter_opts, **subscription_opts)
        subscriptions_manager.subscribe(
          handler.class.to_s,
          handler: self.class.otl_tracer ? otl_trackable_handler(handler) : handler,
          options: { filter: filter_opts, resolve_link_tos: true },
          **subscription_opts
        )
      end

      # Starts the subscriptions manager and optional heartbeat.
      #
      # @return [void]
      def start
        start_heartbeat if Yes::Core.configuration.subscriptions_heartbeat_url.present?
        subscriptions_manager.start
      end

      private

      # Wraps a handler with OpenTelemetry tracing.
      #
      # @param handler [#call] the event handler to wrap
      # @return [Proc] the wrapped handler
      def otl_trackable_handler(handler)
        proc do |event|
          otl_data = Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(
            span_name: handler.class.name,
            span_kind: :consumer,
            links_extractor: ->(ev, **) { ev.metadata['otl_contexts'] },
            track_sql: true
          )
          Yes::Core::OpenTelemetry::OtlSpan.new(otl_data:, otl_tracer: self.class.otl_tracer).
            otl_span(event) { handler.call(event) }
        end
      end

      # Starts a background thread that periodically sends a heartbeat HTTP GET request.
      #
      # @return [Thread] the heartbeat thread
      def start_heartbeat
        Thread.new do
          loop do
            sleep Yes::Core.configuration.subscriptions_heartbeat_interval
            uri = URI(Yes::Core.configuration.subscriptions_heartbeat_url)
            Net::HTTP.get(uri)
          rescue StandardError
            # Keep heartbeat going regardless of errors
          end
        end
      end
    end
  end
end
