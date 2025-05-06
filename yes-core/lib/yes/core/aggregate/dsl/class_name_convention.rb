# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Handles the naming conventions for aggregate-related classes
        #
        # @example
        #   convention = ClassNameConvention.new(context: 'MyContext', aggregate: 'User')
        #   convention.command_class_name('change_name') # => "MyContext::User::Commands::ChangeName::Command"
        #
        class ClassNameConvention
          # @param context [String] The context name
          # @param aggregate [String] The aggregate name
          def initialize(context:, aggregate:)
            @context = context
            @aggregate = aggregate
          end

          # Returns the conventional class name for a given type and name
          #
          # @param type [Symbol] The type of class (:command, :event, or :guard_evaluator, ...)
          # @param name [Symbol, String] The name of the class
          # @return [String] The conventional class name
          def class_name_for(type, name)
            send(:"#{type}_class_name", name)
          end

          private

          attr_reader :context, :aggregate

          def command_class_name(name)
            "#{context}::#{aggregate}::Commands::#{name.to_s.camelize}::Command"
          end

          def event_class_name(name)
            "#{context}::#{aggregate}::Events::#{name.to_s.camelize}"
          end

          def guard_evaluator_class_name(name)
            "#{context}::#{aggregate}::Commands::#{name.to_s.camelize}::GuardEvaluator"
          end

          def state_updater_class_name(name)
            "#{context}::#{aggregate}::Commands::#{name.to_s.camelize}::StateUpdater"
          end

          def read_model_class_name(name)
            name.to_s.camelize
          end

          def read_model_filter_class_name(name)
            "ReadModels::#{name.to_s.camelize}::Filter"
          end

          def read_model_serializer_class_name(name)
            "ReadModels::#{name.to_s.camelize}::Serializers::#{name.to_s.camelize}"
          end

          # Returns the conventional authorizer class name.
          #
          # If +name+ is nil, it refers to the aggregate-level authorizer:
          #   <Context>::<Aggregate>::Commands::<Aggregate>Authorizer
          # Otherwise it refers to a command-level authorizer:
          #   <Context>::<Aggregate>::Commands::<CommandName>::Authorizer
          #
          # @param name [Symbol, String, nil] the command name (optional)
          # @return [String]
          def authorizer_class_name(name)
            return "#{context}::#{aggregate}::Commands::#{aggregate}Authorizer" if name.nil? || name.to_s.empty?

            "#{context}::#{aggregate}::Commands::#{name.to_s.camelize}::Authorizer"
          end
        end
      end
    end
  end
end
