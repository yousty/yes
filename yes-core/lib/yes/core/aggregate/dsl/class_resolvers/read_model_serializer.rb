# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Creates and registers read model serializer classes for aggregates
          #
          # This class resolver generates JSON:API compliant serializer classes
          # for read models. Each serializer class is automatically configured with
          # the specified attributes and type naming conventions.
          #
          # @example Generated read model serializer class structure
          #   class UserSerializer < Yousty::Api::ApplicationSerializer
          #     set_type 'users'
          #     attributes :id, :email, :first_name, :last_name
          #   end
          class ReadModelSerializer < Base
            # Initializes a new read model serializer class resolver
            #
            # @param read_model_name [String] The name of the read model
            # @param context_name [String] The name of the context
            # @param aggregate_name [String] The name of the aggregate
            # @param read_model_attributes [Array<Symbol>] The attributes to be serialized
            def initialize(read_model_name, context_name, aggregate_name, read_model_attributes)
              @read_model_name = read_model_name
              @read_model_attributes = read_model_attributes

              super(context_name, aggregate_name)
            end

            # Creates and registers the read model serializer class in the Yes::Core configuration
            #
            # @return [Class] The found or generated read model serializer class that was registered
            def call
              Yes::Core.configuration.register_read_model_filter_class(
                context_name,
                aggregate_name,
                find_or_generate_class
              )
            end

            private

            # @return [String] The name of the read model
            # @return [Array<Symbol>] The attributes to be serialized
            attr_reader :read_model_name, :read_model_attributes

            # @return [Symbol] Returns :read_model_serializer as the class type
            def class_type
              :read_model_serializer
            end

            # @return [String] The name of the read model serializer class
            def class_name
              read_model_name
            end

            # Generates a new read model serializer class with the required configuration
            #
            # @return [Class] A new serializer class inheriting from Yousty::Api::ApplicationSerializer
            def generate_class
              klass = Class.new(Yousty::Api::ApplicationSerializer)

              klass.set_type read_model_name.pluralize
              klass.attributes(*read_model_attributes)

              klass
            end
          end
        end
      end
    end
  end
end
