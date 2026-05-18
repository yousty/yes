# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module CommandGroup
            # Resolves or generates the Command class for an aggregate-DSL
            # command group. The generated class is a {Yes::Core::Commands::CommandGroup}
            # subclass carrying the group's identity (context, aggregate,
            # group_name) and the ordered list of sub-command names.
            class Command < Base
              private

              def class_type
                :command_group
              end

              def class_name
                command_group_data.name
              end

              def generate_class
                group_name = command_group_data.name
                ctx = command_group_data.context_name
                agg = command_group_data.aggregate_name
                sub_commands = command_group_data.sub_command_names.dup

                Class.new(Yes::Core::Commands::CommandGroup).tap do |klass|
                  klass.context = ctx
                  klass.aggregate = agg
                  klass.group_name = group_name
                  klass.sub_command_names = sub_commands
                end
              end
            end
          end
        end
      end
    end
  end
end
