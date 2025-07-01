# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Creates and registers guard evaluator classes for aggregate commands
            #
            # This class resolver generates plain guard evaluator classes that process
            # commands in aggregates.
            #
            class GuardEvaluator < Base
              private

              # Returns the class type symbol for the guard evaluator
              #
              # @return [Symbol] Returns :guard_evaluator as the class type
              # @api private
              def class_type
                :guard_evaluator
              end

              # Returns the name for the guard evaluator class
              #
              # @return [String] The name of the guard evaluator class derived from the attribute
              # @api private
              def class_name
                command_data.name
              end

              # Creates a new guard evaluator class
              #
              # By default, includes a no_change guard that checks if the command would modify the aggregate's state.
              # This guard is omitted if the command has a custom state_update block since we cannot rely on the default
              # attribute update logic.
              #
              # @return [Class] A new guard evaluator class inheriting from Yes::Core::CommandHandling::GuardEvaluator
              # @api private
              def generate_class # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
                command_name = command_data.name
                context_name = command_data.context_name
                aggregate_name = command_data.aggregate_name

                # Add the no_change guard to the command data's guard names
                # This will be added by the GuardEvaluator unless there's an update_state block
                # or if it was already added by a shortcut expansion
                unless command_data.guard_names.include?(:no_change) || command_data.update_state_block
                  command_data.add_guard(:no_change)
                end

                Class.new(Yes::Core::CommandHandling::GuardEvaluator) do
                  guard :no_change do
                    state_updater_class = Yes::Core.configuration.aggregate_class(
                      context_name, aggregate_name, command_name, :state_updater
                    )

                    next true if state_updater_class.update_state_block

                    payload = raw_payload.except(:"#{aggregate_name.underscore}_id")

                    next true if payload.empty?

                    has_changes = false
                    I18n.with_locale(payload.delete(:locale) || I18n.locale) do
                      payload.each do |attribute, new_value|
                        current_value = public_send(attribute)
                        if current_value != new_value
                          has_changes = true
                          break
                        end
                      end
                    end

                    has_changes
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
