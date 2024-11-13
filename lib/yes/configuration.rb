# frozen_string_literal: true

module Yes
  # Returns the singleton instance of the configuration
  # @return [Yes::Configuration] The configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    def initialize
      @registered_classes = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
    end

    # Register a class for a specific aggregate and type
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param action_name [Symbol, String] The name of the command/event
    # @param type [Symbol] The type (:command, :event, or :handler)
    # @param klass [Class] The class to register
    def register_aggregate_class(aggregate_name, action_name, type, klass)
      @registered_classes[aggregate_name][type][action_name] = klass
    end

    # Register a command class for a specific aggregate
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param command_name [Symbol, String] The name of the command
    # @param klass [Class] The class to register
    def register_command_class(aggregate_name, command_name, klass)
      register_aggregate_class(aggregate_name, command_name, :command, klass)
    end

    # Register an event class for a specific aggregate
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param event_name [Symbol, String] The name of the event
    # @param klass [Class] The class to register
    def register_event_class(aggregate_name, event_name, klass)
      register_aggregate_class(aggregate_name, event_name, :event, klass)
    end

    # Register a handler class for a specific aggregate
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param command_name [Symbol, String] The name of the command
    # @param klass [Class] The class to register
    def register_handler_class(aggregate_name, command_name, klass)
      register_aggregate_class(aggregate_name, command_name, :handler, klass)
    end

    # Retrieve a registered class for a given aggregate, action, and type
    #
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @param action_name [Symbol, String] The name of the action (command/event)
    # @param type [Symbol] The type of the class (:command, :event, or :handler)
    # @return [Class, nil] The registered class or nil if not found
    def aggregate_class(aggregate_name, action_name, type)
      @registered_classes.dig(aggregate_name, type, action_name)
    end

    # List all registered classes for a specific aggregate
    #
    # @param aggregate_name [Symbol, String] The name of the aggregate
    # @return [Hash] A hash of registered classes grouped by type
    def list_aggregate_classes(aggregate_name)
      @registered_classes[aggregate_name]
    end

    # List all registered classes across all aggregates
    #
    # @return [Hash] A complete hash of all registered classes
    def list_all_registered_classes
      @registered_classes
    end
  end
end
