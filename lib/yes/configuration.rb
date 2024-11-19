# frozen_string_literal: true

module Yes
  # Returns the singleton instance of the configuration
  # @return [Yes::Configuration] The configuration instance
  # @example
  #   config = Yes.configuration
  #   config.register_command_class(:user, :create, CreateUserCommand)
  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    def initialize
      @registered_classes = Hash.new do |h, k|
        h[k] = Hash.new { |h2, k2| h2[k2] = {} }
      end
    end

    # Register a class for a specific aggregate and type
    # @param context_name [Symbol, String] The context for the aggregate
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param action_name [Symbol, String] The name of the command/event
    # @param type [Symbol] The type (:command, :event, or :handler)
    # @param klass [Class] The class to register
    # @example Register a command class
    #   register_aggregate_class(:authentication, :user, :create, :command, CreateUserCommand)
    def register_aggregate_class(context_name, aggregate_name, action_name, type, klass)
      key = [context_name, aggregate_name]
      @registered_classes[key][type][action_name] = klass
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

    # Register a handler class for a specific aggregate
    # @param context_name [Symbol, String] The context for the aggregate
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param command_name [Symbol, String] The name of the command
    # @param klass [Class] The class to register
    # @example
    #   register_handler_class(:authentication, :user, :create, CreateUserHandler)
    def register_handler_class(context_name, aggregate_name, command_name, klass)
      register_aggregate_class(context_name, aggregate_name, command_name, :handler, klass)
    end

    # Retrieve a registered class for a given aggregate, action, and type
    # @param context_name [Symbol, String] The context for the aggregate
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param action_name [Symbol, String] The name of the action (command/event)
    # @param type [Symbol] The type of the class (:command, :event, or :handler)
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
    #   classes = list_aggregate_classes(:authentication, :user)
    def list_aggregate_classes(context_name, aggregate_name)
      @registered_classes[[context_name, aggregate_name]]
    end

    # List all registered classes across all aggregates and contexts
    # @return [Hash] A complete hash of all registered classes
    # @example
    #   all_classes = list_all_registered_classes
    #   # Returns:
    #   # {
    #   #   [:authentication, :user] => {
    #   #     command: { create: CreateUserCommand },
    #   #     event: { created: UserCreatedEvent }
    #   #   },
    #   #   [:content, :user] => {
    #   #     command: { update_profile: UpdateUserProfileCommand }
    #   #   }
    #   # }
    def list_all_registered_classes
      @registered_classes
    end
  end
end
