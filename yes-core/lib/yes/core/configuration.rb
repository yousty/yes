# frozen_string_literal: true

module Yes
  module Core
    # Returns the singleton instance of the configuration
    # @return [Yes::Core::Configuration] The configuration instance
    # @example
    #   config = Yes::Core.configuration
    #   config.register_command_class(:user, :create, CreateUserCommand)
    def self.configuration
      @configuration ||= Configuration.new
    end

    class Configuration
      # Initializes a new configuration instance with nested hashes for class storage.
      def initialize
        @registered_classes = Hash.new do |h, k|
          h[k] = Hash.new { |h2, k2| h2[k2] = {} }
        end
      end

      # Register a class for a specific aggregate and type
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param action_name [Symbol, String] The name of the command/event
      # @param type [Symbol] The type (:command, :event, or :guard_evaluator)
      # @param klass [Class] The class to register
      # @example Register a command class
      #   register_aggregate_class(:authentication, :user, :create, :command, CreateUserCommand)
      def register_aggregate_class(context_name, aggregate_name, action_name, type, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][type][action_name] = klass
      end

      # Register a read model class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param klass [Class] The class to register
      # @example
      #   register_read_model_class(:authentication, :user, UserReadModel)
      def register_read_model_class(context_name, aggregate_name, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][:read_model] = klass
      end

      # Register a read model filter class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param klass [Class] The class to register
      # @example
      #   register_read_model_filter_class(:authentication, :user, UserReadModelFilter)
      def register_read_model_filter_class(context_name, aggregate_name, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][:read_model_filter] = klass
      end

      # Register a command class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param klass [Class] The class to register
      # @example
      #   register_command_class(:authentication, :user, :create, CreateUserCommand)
      def register_command_class(context_name, aggregate_name, command_name, klass)
        register_aggregate_class(context_name, aggregate_name, command_name, :command, klass)
      end

      # Register an event class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param event_name [Symbol, String] The name of the event
      # @param klass [Class] The class to register
      # @example
      #   register_event_class(:authentication, :user, :created, UserCreatedEvent)
      def register_event_class(context_name, aggregate_name, event_name, klass)
        register_aggregate_class(context_name, aggregate_name, event_name, :event, klass)
      end

      # Register a guard evaluator class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param klass [Class] The class to register
      # @example
      #   register_guard_evaluator_class(:authentication, :user, :create, CreateUserGuardEvaluator)
      def register_guard_evaluator_class(context_name, aggregate_name, command_name, klass)
        register_aggregate_class(context_name, aggregate_name, command_name, :guard_evaluator, klass)
      end

      # Register an aggregate authorizer class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param klass [Class] The authorizer class to register
      # @example
      #   register_aggregate_authorizer_class(:authentication, :user, UserAuthorizer)
      def register_aggregate_authorizer_class(context_name, aggregate_name, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][:aggregate_authorizer] = klass
      end

      # Register a command authorizer class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param klass [Class] The authorizer class to register
      # @example
      #   register_command_authorizer_class(:sales, :user, :create, CreateUserAuthorizer)
      def register_command_authorizer_class(context_name, aggregate_name, command_name, klass)
        register_aggregate_class(context_name, aggregate_name, command_name, :authorizer, klass)
      end

      # Register the event(s) associated with a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param event_names [Array<Symbol, String>] An array of event names
      # @example
      #   register_command_events(:authentication, :user, :create, [:user_created, :welcome_email_sent])
      def register_command_events(context_name, aggregate_name, command_name, event_names)
        key = [context_name, aggregate_name]
        mappings = @registered_classes[key][:command_event_mappings] ||= {}
        mappings[command_name] = event_names
      end

      # Retrieve all command-to-event mappings for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @return [Hash] A hash where keys are command names and values are arrays of event names
      # @example
      #   mappings = command_event_mappings(:authentication, :user)
      def command_event_mappings(context_name, aggregate_name)
        key = [context_name, aggregate_name]
        @registered_classes[key][:command_event_mappings] || {}
      end

      # Retrieve the event names associated with a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @return [Array<Symbol, String>] An array of event names associated with the command, or an empty array if none
      # @example
      #   event_names = command_event_mapping(:authentication, :user, :create)
      def command_event_mapping(context_name, aggregate_name, command_name)
        command_event_mappings(context_name, aggregate_name)[command_name] || []
      end

      # Retrieve the actual event classes associated with a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @return [Array<Class>] An array of event classes associated with the command
      # @example
      #   event_classes = event_classes_for_command(:authentication, :user, :create)
      def event_classes_for_command(context_name, aggregate_name, command_name)
        command_event_mapping(context_name, aggregate_name, command_name).map do |event_name|
          aggregate_class(context_name, aggregate_name, event_name, :event)
        end
      end

      # Retrieve a registered class for a given aggregate, action, and type
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param action_name [Symbol, String] The name of the action (command/event)
      # @param type [Symbol] The type of the class (:command, :event, or :guard_evaluator)
      # @return [Class, nil] The registered class or nil if not found
      # @example Get a command class
      #   command_class = aggregate_class(:authentication, :user, :create, :command)
      def aggregate_class(context_name, aggregate_name, action_name, type)
        @registered_classes.dig([context_name, aggregate_name], type, action_name)
      end

      # List all registered classes for a specific aggregate in a context
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @return [Hash] A hash of registered classes grouped by type
      # @example
      #   classes = list_aggregate_classes("Authentication", "User)
      def list_aggregate_classes(context_name, aggregate_name)
        @registered_classes[[context_name, aggregate_name]]
      end

      # Retrieve a guard evaluator class for a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @return [Class, nil] The registered guard evaluator class or nil if not found
      # @example
      #   evaluator = guard_evaluator_class(:authentication, :user, :create)
      def guard_evaluator_class(context_name, aggregate_name, command_name)
        aggregate_class(context_name, aggregate_name, command_name.to_s.underscore.to_sym, :guard_evaluator)
      end

      # List all registered classes across all aggregates and contexts
      # @return [Hash] A complete hash of all registered classes
      # @example
      #   all_classes = list_all_registered_classes
      #   # Returns:
      #   # {
      #   #   [:authentication, :user] => {
      #   #     command: { create: CreateUserCommand },
      #   #     event: { created: UserCreatedEvent },
      #   #     guard_evaluator: { create: CreateUserGuardEvaluator }
      #   #   }
      #   # }
      def list_all_registered_classes
        @registered_classes
      end
    end
  end
end
