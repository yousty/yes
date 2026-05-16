# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module CommandGroup
            # Base class for command_group-related class resolvers.
            #
            # Mirrors {ClassResolvers::Command::Base} but binds to
            # {CommandGroupData} instead of {CommandData}.
            #
            # @abstract Subclass and implement {ClassResolvers::Base#class_type},
            #   {ClassResolvers::Base#class_name}, and
            #   {ClassResolvers::Base#generate_class}.
            class Base < ClassResolvers::Base
              # @param command_group_data [Yes::Core::Aggregate::Dsl::CommandGroupData]
              def initialize(command_group_data)
                @command_group_data = command_group_data

                super(command_group_data.context_name, command_group_data.aggregate_name)
              end

              private

              attr_reader :command_group_data
            end
          end
        end
      end
    end
  end
end
