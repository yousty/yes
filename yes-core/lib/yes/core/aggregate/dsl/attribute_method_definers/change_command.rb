# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeMethodDefiners
          # Defines the change command method for an attribute
          class ChangeCommand < Base
            # Defines a change command method on the aggregate class
            # @return [void]
            def call
              command_method = :"change_#{name}"
              name = @name

              aggregate_class.define_method(command_method) do |**payload|
                cmd = command_utilities.build_command(name, payload)
                handler_class = command_utilities.fetch_handler_class(name)

                response = execute_command(cmd, handler_class)
                update_read_model(name => payload[name]) if response.success?

                response
              end
            end
          end
        end
      end
    end
  end
end
