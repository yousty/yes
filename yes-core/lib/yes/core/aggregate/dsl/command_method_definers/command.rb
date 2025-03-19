# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module CommandMethodDefiners
          # Defines a command method on the aggregate class
          class Command < Base
            # @return [void]
            def call
              command_name = @name

              aggregate_class.define_method(command_name) do |payload = {}|
                payload = command_utilities.prepare_payload(command_name, payload)
                cmd = command_utilities.build_command(command_name, payload)
                guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)

                response = execute_command(cmd, guard_evaluator_class)

                if response.success?
                  update_read_model(
                    payload.except(:"#{self.class.aggregate.underscore}_id").merge(
                      revision: response.event.stream_revision
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
