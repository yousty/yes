# frozen_string_literal: true

module Yes
  module Core
    # Handles command and handler class operations for aggregates
    #
    # @since 0.1.0
    # @api private
    class CommandUtilities
      COMMAND_TO_EVENT_VERBS = {
        'Change' => 'Changed',
        'Add' => 'Added',
        'Remove' => 'Removed',
        'Enable' => 'Enabled',
        'Disable' => 'Disabled',
        'Activate' => 'Activated',
        'Deactivate' => 'Deactivated',
        'Open' => 'Opened',
        'Close' => 'Closed',
        'Start' => 'Started',
        'Stop' => 'Stopped',
        'Submit' => 'Submitted',
        'Approve' => 'Approved',
        'Reject' => 'Rejected',
        'Confirm' => 'Confirmed',
        'Cancel' => 'Cancelled',
        'Complete' => 'Completed',
        'Fail' => 'Failed',
        'Resolve' => 'Resolved',
        'Reopen' => 'Reopened',
        'Reactivate' => 'Reactivated'
      }.freeze

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
      # @param command_name [String] The command name
      # @param event_name [String, nil] Optional explicit event name to use
      # @param metadata [Hash] Event metadata
      # @return [PgEventstore::Event] The event instance
      def build_event(payload:, command_name:, event_name: nil, metadata: {})
        event_class = resolve_event_class(command_name:, event_name:)
        event_class.new(
          type: event_type(command_name:, event_name:),
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

      # Resolves the event class to use
      #
      # @param command_name [String] The command name
      # @param event_name [String, nil] Optional explicit event name to use
      # @return [Class] The event class
      def resolve_event_class(command_name:, event_name: nil)
        "#{context}::#{aggregate}::Events::#{event_name || resolved_event_name(command_name:)}".constantize
      end

      # Builds the event type string
      #
      # @param command_name [String] The command name
      # @param event_name [String, nil] Optional explicit event name to use
      # @return [String] The event type
      def event_type(command_name:, event_name: nil)
        "#{context}::#{aggregate}#{event_name || resolved_event_name(command_name:)}"
      end

      # Resolves the event name to use by converting command name to event name
      # For example: ChangeLocation -> LocationChanged
      #
      # @param command_name [String] The command name
      # @return [String] The resolved event name
      def resolved_event_name(command_name:)
        COMMAND_TO_EVENT_VERBS.each do |command_verb, event_verb|
          next unless command_name.start_with?(command_verb)

          # Extract the subject (e.g. "Location" from "ChangeLocation")
          subject = command_name.delete_prefix(command_verb)
          # Return subject + verb (e.g. "LocationChanged")
          return "#{subject}#{event_verb}"
        end

        command_name
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
