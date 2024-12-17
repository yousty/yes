# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module AttributeMethodDefiners
        # Defines the can_change? method for an attribute
        class CanChangeCommand < Base
          # Defines a method that checks if an attribute can be changed
          # @return [void]
          def call
            can_change_method = "can_change_#{name}?"
            error_method = "#{name}_change_error"

            aggregate_class.attr_accessor error_method
            name = @name

            aggregate_class.define_method(can_change_method) do |**payload|
              command = build_command(name, payload)
              handler_class = fetch_handler_class(name)

              handler_class.new(command, publish_events: false).call
              send(:"#{error_method}=", nil)
              true
            rescue CommandHandler::InvalidTransition, CommandHandler::NoChangeTransition,
                   Yousty::Eventsourcing::Command::Invalid => e
              send(:"#{error_method}=", e.message)
              false
            end
          end
        end
      end
    end
  end
end 