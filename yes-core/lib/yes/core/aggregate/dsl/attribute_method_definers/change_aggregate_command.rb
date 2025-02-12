# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeMethodDefiners
          # Defines the change command method for an aggregate attribute that accepts an aggregate instance
          class ChangeAggregateCommand < Base
            # Defines a change command method on the aggregate class that accepts an aggregate instance
            # @return [void]
            def call
              command_method = :"change_#{name}"
              name = @name
              id_name = :"#{name}_id"

              aggregate_class.define_method(command_method) do |**payload|
                aggregate_instance = payload[name]
                cmd = command_utilities.build_command(name, { id_name => aggregate_instance.id })
                guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(name)

                response = execute_command(cmd, guard_evaluator_class)
                if response.success?
                  update_read_model(id_name => aggregate_instance.id,
                                    revision: response.event.stream_revision)
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
