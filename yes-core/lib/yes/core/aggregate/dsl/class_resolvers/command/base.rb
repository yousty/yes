# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Base class for command-related class resolvers
            #
            # This class extends the base resolver functionality to handle
            # command-specific class generation. It provides a foundation for
            # resolvers that need to work with commands, such as command classes
            # and their associated events.
            #
            # @abstract Subclass and implement the required methods from {ClassResolvers::Base}
            class Base < ClassResolvers::Base
              # Initializes a new command-based class resolver
              #
              # @param command_data [Yes::Core::Aggregate::Dsl::CommandData] The command data instance
              #   containing metadata about the command being processed
              def initialize(command_data)
                @command_data = command_data

                super(command_data.context_name, command_data.aggregate_name)
              end

              private

              # @return [Yes::Core::Aggregate::Dsl::CommandData] The command data instance
              attr_reader :command_data
            end
          end
        end
      end
    end
  end
end
