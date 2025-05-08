# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Command
            # Defines a command method on the aggregate class
            class Command < Base
              # @return [void]
              def call
                command_name = @name

                aggregate_class.define_method(command_name) do |payload = {}|
                  payload = command_utilities.prepare_command_payload(command_name, payload)
                  cmd = command_utilities.build_command(command_name, payload)
                  guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)
                  state_updater_class = command_utilities.fetch_state_updater_class(command_name)

                  response = execute_command(cmd, guard_evaluator_class)

                  if response.success?
                    locale = payload.delete(:locale)
                    state_updater = state_updater_class.new(payload:, aggregate: self)
                    update_read_model(
                      state_updater.call.merge(
                        revision: response.event.stream_revision,
                        locale:
                      )
                    )
                  end

                  response
                end
              end
            end
          end
        end
      end
    end
  end
end
