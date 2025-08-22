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
                  execute_command_and_update_state(command_name, payload)
                end
              end
            end
          end
        end
      end
    end
  end
end
