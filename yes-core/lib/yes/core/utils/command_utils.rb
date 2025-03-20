# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Handles command and handler class operations for aggregates
      #
      # @since 0.1.0
      # @api private
      class CommandUtils
        # @param context [String] The context namespace
        # @param aggregate [String] The aggregate name
        # @param aggregate_id [String] The ID of the aggregate
        def initialize(context:, aggregate:, aggregate_id:)
          @context = context
          @aggregate = aggregate
          @aggregate_id = aggregate_id
        end

        # Builds a change command instance for the given attribute and payload
        #
        # @param attribute [Symbol] The attribute name
        # @param payload [Hash] The command payload
        # @return [Yes::Core::Command] The instantiated command
        # @raise [RuntimeError] If the command class cannot be found
        def build_attribute_command(attribute, payload)
          build_command(:"change_#{command_name(attribute)}", payload)
        end

        # Builds a command instance for the given command name and payload
        #
        # @param command_name [Symbol] The command name
        # @param payload [Hash] The command payload
        # @return [Yes::Core::Command] The instantiated command
        # @raise [RuntimeError] If the command class cannot be found
        def build_command(command_name, payload)
          command_class = fetch_class(command_name, :command)
          command_class.new("#{aggregate.underscore}_id": aggregate_id, **payload)
        end

        # Fetches the guard evaluator class for a given attribute name
        #
        # @param name [Symbol] The attribute name
        # @return [Class] The guard evaluator class
        # @raise [RuntimeError] If the guard evaluator class cannot be found
        def fetch_attribute_guard_evaluator_class(name)
          fetch_guard_evaluator_class(:"change_#{command_name(name)}")
        end

        # Fetches the guard evaluator class for a given command name
        #
        # @param name [Symbol] The command name
        # @return [Class] The guard evaluator class
        # @raise [RuntimeError] If the guard evaluator class cannot be found
        def fetch_guard_evaluator_class(name)
          fetch_class(name, :guard_evaluator)
        end

        # Builds a PgEventstore::Event instance
        #
        # @param command_name [Symbol] The command name
        # @param payload [Hash] The event payload
        # @param metadata [Hash] Event metadata
        # @return [PgEventstore::Event] The event instance
        def build_event(command_name:, payload:, metadata: {})
          event_class = Yes::Core.configuration.event_classes_for_command(context, aggregate, command_name).first
          event_class.new(
            type: "#{context}::#{aggregate}#{event_class.name.demodulize}",
            data: payload,
            metadata:
          )
        end

        # Builds a PgEventstore::Stream instance
        #
        # @param context [String] The context name
        # @param name [String] The stream name
        # @param id [String] The stream ID
        # @return [PgEventstore::Stream] The stream instance
        def build_stream(context: @context, name: @aggregate, id: @aggregate_id)
          PgEventstore::Stream.new(
            context:,
            stream_name: name,
            stream_id: id
          )
        end

        # Gets the current revision of a stream
        #
        # @param stream [PgEventstore::Stream] The stream to check
        # @return [Integer] The current revision
        def stream_revision(stream)
          PgEventstore.client.read(
            stream,
            options: { direction: 'Backwards', max_count: 1 },
            middlewares: []
          ).first&.stream_revision || 0
        rescue PgEventstore::StreamNotFoundError
          :no_stream
        end

        def prepare_payload(attribute, payload)
          return payload if payload.is_a?(Hash)

          { attribute => payload }
        end

        private

        attr_reader :context, :aggregate, :aggregate_id

        # Fetches a class based on the command name and type
        #
        # @param command [Symbol] The command name
        # @param type [Symbol] The type of class to fetch (:command or :guard_evaluator)
        # @return [Class] The requested class
        # @raise [RuntimeError] If the requested class cannot be found
        def fetch_class(command, type)
          klass = Yes::Core.configuration.aggregate_class(context, aggregate, command, type)
          raise "#{type.to_s.tr('_', ' ').capitalize} class not found for #{command}" unless klass

          klass
        end

        # Removes the '_id' suffix from an attribute name
        #
        # @param attribute [Symbol, String] The attribute name that might contain an '_id' suffix
        # @return [String] The attribute name without the '_id' suffix
        # @example
        #   command_name(:user_id) # => "user"
        #   command_name("company_id") # => "company"
        #   command_name(:name) # => "name"
        def command_name(attribute)
          attribute.to_s.sub('_id', '')
        end
      end
    end
  end
end
