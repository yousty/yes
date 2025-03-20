# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Factory class that creates and defines commands on aggregates
        #
        # @example
        #   command_data = CommandData.new(name: :assign_user, aggregate_class: Company)
        #   CommandDefiner.new(command_data).call do
        #     payload user_id: :uuid
        #
        #     guard :user_already_assigned do
        #       user_id.present?
        #     end
        #
        #     update_state do
        #       some_attribute { payload.xyz }
        #       another_attribute { "#{payload.abc}_#{email}" }
        #     end
        #   end
        #
        class CommandDefiner
          # Error raised when a command is defined with payload attributes that are not defined on the aggregate
          class UndefinedAttributeError < StandardError; end

          # @return [CommandData] the data object containing command configuration
          attr_reader :command_data
          private :command_data

          # Initializes a new CommandDefiner instance
          #
          # @param command_data [CommandData] the data object containing command configuration
          # @return [CommandDefiner] a new instance of CommandDefiner
          def initialize(command_data)
            @command_data = command_data
          end

          # Generates and registers all necessary classes for the command.
          # This includes command classes, event classes, and guard evaluator classes,
          # as well as defining related methods on the aggregate class.
          #
          # @param block [Proc] Optional block for defining payload, guards and other command configurations
          # @return [void]
          # @raise [UndefinedAttributeError] If the command is defined with payload attributes that are not defined on
          # the aggregate
          def call(&block)
            # defines an empty guard evaluator class, because we don't have any default guards defined
            @guard_evaluator_class = ClassResolvers::Command::GuardEvaluator.new(command_data).call
            @state_updater_class = ClassResolvers::Command::StateUpdater.new(command_data).call
            evaluate_dsl_block(&block) if block

            if command_data.update_state_block
              validate_state_update_attributes!
            else
              validate_payload_attributes!
            end

            @command_class = ClassResolvers::Command::Command.new(command_data).call
            @event_class = ClassResolvers::Command::Event.new(command_data).call
            MethodDefiners::Command::Command.new(command_data).call
            MethodDefiners::Command::CanCommand.new(command_data).call

            register_command_events
          end

          private

          # Validates that all payload attributes are defined on the aggregate
          #
          # @return [void]
          # @raise [UndefinedAttributeError] If the command is defined with payload attributes that are not defined on
          # the aggregate
          def validate_payload_attributes!
            return if command_data.payload_attributes.empty?

            aggregate_attributes = command_data.aggregate_class.attributes
            undefined_attributes = command_data.payload_attributes.keys.reject do |attr_name|
              aggregate_attributes.key?(attr_name)
            end

            return if undefined_attributes.empty?

            raise UndefinedAttributeError, "Command '#{command_data.name}' is defined with payload attributes " \
                                           "that are not defined on the aggregate: #{undefined_attributes.join(', ')}. " \
                                           "Please define these attributes using the 'attribute' method first."
          end

          # Validates that all attributes used in the update_state block are defined on the aggregate
          #
          # @return [void]
          # @raise [UndefinedAttributeError] If the update_state block uses attributes that are not defined on the aggregate
          def validate_state_update_attributes!
            return unless @state_updater_class.updated_attributes

            aggregate_attributes = command_data.aggregate_class.attributes
            undefined_attributes = @state_updater_class.updated_attributes.reject do |attr_name|
              aggregate_attributes.key?(attr_name)
            end

            return if undefined_attributes.empty?

            raise UndefinedAttributeError, "Command '#{command_data.name}' update_state block uses attributes " \
                                           "that are not defined on the aggregate: #{undefined_attributes.join(', ')}. " \
                                           "Please define these attributes using the 'attribute' method first."
          end

          def register_command_events
            Yes::Core.configuration.register_command_events(
              command_data.context_name,
              command_data.aggregate_name,
              command_data.name,
              [command_data.event_name]
            )
          end

          # Evaluates the DSL block in the context of a DslEvaluator
          #
          # @param block [Proc] The block to evaluate
          # @return [void]
          def evaluate_dsl_block(&block)
            return unless block

            dsl_evaluator = DslEvaluator.new(command_data, @guard_evaluator_class, @state_updater_class)
            dsl_evaluator.instance_eval(&block)
          end

          # DSL evaluator class for command configuration blocks
          class DslEvaluator
            # @return [CommandData] The command data being configured
            # @return [Class] The guard evaluator class for this command
            # @return [Class] The state updater class for this command
            attr_reader :command_data, :guard_evaluator_class, :state_updater_class

            # @param command_data [CommandData] The command data to configure
            # @param guard_evaluator_class [Class] The guard evaluator class for this command
            # @param state_updater_class [Class] The state updater class for this command
            def initialize(command_data, guard_evaluator_class, state_updater_class)
              @command_data = command_data
              @guard_evaluator_class = guard_evaluator_class
              @state_updater_class = state_updater_class
            end

            # Defines a guard for the command
            #
            # @param name [Symbol] The name of the guard
            # @param block [Proc] The guard evaluation block
            # @return [void]
            def guard(name, &)
              command_data.add_guard(name)
              guard_evaluator_class.guard(name, &)
            end

            # Defines the payload for the command
            #
            # @param attributes [Hash] The attributes for the payload
            # @return [void]
            def payload(attributes)
              command_data.payload_attributes = attributes
            end

            # Defines how the state should be updated
            #
            # @param block [Proc] The block defining how to update the state
            # @return [void]
            def update_state(&block)
              command_data.update_state_block = block
              state_updater_class.update_state(&block)
            end

            # Defines the event name for the command
            #
            # @param name [Symbol] The name of the event
            # @return [void]
            def event(name)
              command_data.event_name = name
            end
          end
        end
      end
    end
  end
end
