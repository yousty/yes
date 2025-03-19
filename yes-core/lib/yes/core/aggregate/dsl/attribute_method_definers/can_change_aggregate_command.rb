# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeMethodDefiners
          # Defines the can_change? method for an aggregate attribute that accepts an aggregate instance
          class CanChangeAggregateCommand < Base
            # Defines a can_change? method on the aggregate class that accepts an aggregate instance
            # @return [void]
            def call # rubocop:disable Metrics/AbcSize
              can_change_method = :"can_change_#{name}?"
              error_method = :"change_#{name}_error"
              name = @name
              id_name = :"#{name}_id"

              aggregate_class.attr_accessor error_method

              aggregate_class.define_method(can_change_method) do |payload|
                payload = command_utilities.prepare_payload(name, payload)
                aggregate_instance = payload[name]
                cmd = command_utilities.build_attribute_command(name, { id_name => aggregate_instance.id })
                guard_evaluator_class = command_utilities.fetch_attribute_guard_evaluator_class(name)

                # handle_command returns a guard evaluator instance if successful
                send(:handle_command, cmd, guard_evaluator_class).present?
              rescue Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition,
                     Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
                     Yousty::Eventsourcing::Command::Invalid
                false
              end
            end
          end
        end
      end
    end
  end
end
