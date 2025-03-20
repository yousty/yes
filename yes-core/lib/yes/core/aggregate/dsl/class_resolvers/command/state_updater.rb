# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Creates and registers state updater classes for aggregate commands
            #
            # This class resolver generates plain state updater class that process
            # custom state updates in aggregates.
            #
            class StateUpdater < Base
              private

              # Returns the class type symbol for the state updater
              #
              # @return [Symbol] Returns :state_updater as the class type
              # @api private
              def class_type
                :state_updater
              end

              # Returns the name for the state updater class
              #
              # @return [String] The name of the state updater class derived from the command
              # @api private
              def class_name
                command_data.name
              end

              # Creates a new state updater class
              #
              # @return [Class] A new state updater class inheriting from Yes::Core::CommandHandling::StateUpdater
              # @api private
              def generate_class
                Class.new(Yes::Core::CommandHandling::StateUpdater)
              end
            end
          end
        end
      end
    end
  end
end
