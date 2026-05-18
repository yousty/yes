# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Data object that holds information about a command_group definition
        # in an aggregate.
        #
        # @example
        #   CommandGroupData.new(:create_apprenticeship, MyAggregate, context: 'Companies', aggregate: 'Apprenticeship')
        class CommandGroupData
          attr_reader :name, :context_name, :aggregate_name, :aggregate_class
          attr_accessor :sub_command_names, :guard_names

          # @param name [Symbol] the name of the command group
          # @param aggregate_class [Class] the aggregate class the group belongs to
          # @param options [Hash] additional options
          # @option options [String] :context the context name
          # @option options [String] :aggregate the aggregate name
          def initialize(name, aggregate_class, options = {})
            @name = name
            @aggregate_class = aggregate_class
            @context_name = options[:context]
            @aggregate_name = options[:aggregate]
            @sub_command_names = []
            @guard_names = []
          end

          # @param name [Symbol] sub-command name to append (preserves order)
          # @return [void]
          def add_sub_command(name)
            @sub_command_names << name
          end

          # @param name [Symbol] guard name to record on this group
          # @return [void]
          def add_guard(name)
            @guard_names << name
          end
        end
      end
    end
  end
end
