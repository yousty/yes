# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Data object that holds information about a command definition in an aggregate
        #
        # @example
        #   CommandData.new(:assign_user, UserAggregate, context: 'Users', aggregate: 'User')
        #
        class CommandData
          attr_reader :name, :context_name, :aggregate_name, :aggregate_class
          attr_accessor :event_name, :payload_attributes, :update_state_block, :guard_names

          # @param name [Symbol] The name of the command
          # @param aggregate_class [Class] The aggregate class this command belongs to
          # @param options [Hash] Additional options for the command
          # @option options [String] :context The context name for the command
          # @option options [String] :aggregate The aggregate name
          # @option options [Hash] :payload_attributes The payload attributes for the command
          def initialize(name, aggregate_class, options = {})
            @name = name
            @aggregate_class = aggregate_class
            @context_name = options.delete(:context)
            @aggregate_name = options.delete(:aggregate)

            # Default event name based on command name (will be overridden if specified in DSL)
            @event_name = resolved_event_name

            # Default payload is just the aggregate_id
            @payload_attributes = options.delete(:payload_attributes) || {}

            # Store guard names
            @guard_names = []
          end

          # Resolves the event name based on the command name using CommandUtilities
          #
          # @return [Symbol] The resolved event name
          def resolved_event_name
            # Create a temporary CommandUtilities instance to use its resolved_event_name method
            command_utilities = Yes::Core::CommandUtilities.new(
              context: context_name,
              aggregate: aggregate_name,
              aggregate_id: nil # Not needed for resolving event name
            )

            # Convert command name to camel case for CommandUtilities
            camelized_command = name.to_s.camelize

            # Use CommandUtilities to resolve the event name
            event_name = command_utilities.send(:resolved_event_name, command_name: camelized_command)

            # Convert to symbol
            event_name.underscore.to_sym
          end

          # Add a guard name to the list of guards
          #
          # @param name [Symbol] The name of the guard
          # @return [void]
          def add_guard(name)
            @guard_names << name
          end
        end
      end
    end
  end
end
