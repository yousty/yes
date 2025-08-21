# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Handles command and handler class operations for aggregates
      #
      # @since 0.1.0
      # @api private
      class CommandUtils
        ASSIGN_COMMAND_PREFIX = 'assign_'

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
          build_command(:"change_#{attribute}", payload)
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

        # Fetches the guard evaluator class for a given command name
        #
        # @param name [Symbol] The command name
        # @return [Class] The guard evaluator class
        # @raise [RuntimeError] If the guard evaluator class cannot be found
        def fetch_guard_evaluator_class(name)
          fetch_class(name, :guard_evaluator)
        end

        # Fetches the state updater class for a given command name
        #
        # @param name [Symbol] The command name
        # @return [Class] The state updater class
        def fetch_state_updater_class(name)
          fetch_class(name, :state_updater)
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

        def prepare_assign_command_payload(command_name, payload)
          return payload unless command_name.to_s.starts_with?(ASSIGN_COMMAND_PREFIX)

          attribute_name = command_name.to_s.split(ASSIGN_COMMAND_PREFIX).last.to_sym
          name_with_id = :"#{attribute_name}_id"
          key = payload.key?(attribute_name) ? attribute_name : name_with_id

          return payload unless payload[key].is_a?(Yes::Core::Aggregate)

          payload[name_with_id] = payload.delete(key).id
          payload
        end

        def command_name_from_event(event, aggregate_class)
          event_name = event.type.split('::').last.sub(event.stream.stream_name, '').underscore
          aggregate_class.commands.values.find { _1.event_name.to_s == event_name }.name
        end

        # Prepares the payload for a command
        #
        # @param command_name [Symbol] The command name
        # @param payload [Hash] The command payload
        # @param aggregate_class [Class] The aggregate class
        # @return [Hash] The prepared payload
        def prepare_command_payload(command_name, payload, aggregate_class)
          return append_locale_param(command_name, payload, aggregate_class) if payload.is_a?(Hash)

          payload_attributes = aggregate_class.commands[command_name].payload_attributes.except(:locale)
          if payload_attributes.length > 1
            raise 'Payload attributes must be a Hash with a single key (not including locale key)'
          end

          append_locale_param(command_name, { payload_attributes.keys.first => payload }, aggregate_class)
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

        # Adds locale param to payload if required and not present
        #
        # @param command_name [Symbol] The command name
        # @param payload [Hash] The command payload
        # @param aggregate_class [Class] The aggregate class
        # @return [Hash] The prepared payload
        def append_locale_param(command_name, payload, aggregate_class)
          return payload if payload.key?(:locale)
          return payload unless aggregate_class.commands[command_name].payload_attributes.key?(:locale)

          payload.merge(locale: I18n.locale.to_s)
        end
      end
    end
  end
end
