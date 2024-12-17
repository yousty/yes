# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module AttributeMethodDefiners
        # Defines the change command method for an attribute
        class ChangeCommand < Base
          # Defines a change command method on the aggregate class
          # @return [void]
          def call
            command_method = :"change_#{name}"
            name = @name

            aggregate_class.define_method(command_method) do |**payload|
              return false unless send(:"can_change_#{name}?", **payload)

              command = build_command(name, payload)
              handler_class = fetch_handler_class(name)
              handler = handler_class.new(command, revision_check: false)
              # only run base class call method which publishes events
              result = Yes::CommandHandler.instance_method(:call).bind_call(handler)
              update_read_model(name => payload[name]) if result
              result
            end
          end
        end
      end
    end
  end
end 