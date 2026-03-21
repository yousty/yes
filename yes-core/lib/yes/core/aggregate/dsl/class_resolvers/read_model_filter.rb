# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Creates and registers read model filter classes for aggregates
          #
          # This class resolver generates filter classes that provide query scopes
          # for read models. Each filter class is automatically configured with
          # basic scopes and a reference to its corresponding read model class.
          #
          # @example Generated read model filter class structure
          #   class UserFilter < Yes::Core::ReadModel::Filter
          #     has_scope :ids do |_, scope, value|
          #       scope.by_ids(value.split(','))
          #     end
          #
          #     private
          #
          #     def read_model_class
          #       Test::User::Aggregate.read_model_class
          #     end
          #   end
          class ReadModelFilter < Base
            # Initializes a new read model filter class resolver
            #
            # @param read_model_name [String] The name of the read model
            # @param context_name [String] The name of the context
            # @param aggregate_name [String] The name of the aggregate
            def initialize(read_model_name, context_name, aggregate_name)
              @read_model_name = read_model_name

              super(context_name, aggregate_name)
            end

            # Creates and registers the read model filter class in the Yes::Core configuration
            #
            # @return [Class] The found or generated read model filter class that was registered
            def call
              Yes::Core.configuration.register_read_model_filter_class(
                context_name,
                aggregate_name,
                find_or_generate_class
              )
            end

            private

            # @return [String] The name of the read model
            attr_reader :read_model_name

            # @return [Symbol] Returns :read_model_filter as the class type
            def class_type
              :read_model_filter
            end

            # @return [String] The name of the read model filter class
            def class_name
              read_model_name
            end

            # Generates a new read model filter class with the required scopes and configuration
            #
            # @return [Class] A new filter class inheriting from Yes::Core::ReadModel::Filter
            def generate_class
              klass = Class.new(Yes::Core::ReadModel::Filter)

              klass.has_scope :ids do |_, scope, value|
                scope.by_ids(value.split(','))
              end

              # Define read_model_class method
              aggregate_class_name = "#{context_name}::#{aggregate_name}::Aggregate"
              klass.define_method(:read_model_class) do
                aggregate_class_name.constantize.read_model_class
              end
              klass.send :private, :read_model_class

              klass
            end
          end
        end
      end
    end
  end
end
