# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module CommandGroup
            # Resolves or generates the GuardEvaluator class for a command_group.
            #
            # Unlike the per-command resolver, no `:no_change` guard is
            # auto-injected — command groups are intended to be lighter on
            # guard checks and rely on whatever set of guards the user
            # declares explicitly in the DSL block.
            class GuardEvaluator < Base
              private

              def class_type
                :command_group_guard_evaluator
              end

              def class_name
                command_group_data.name
              end

              def generate_class
                Class.new(Yes::Core::CommandHandling::GuardEvaluator)
              end
            end
          end
        end
      end
    end
  end
end
