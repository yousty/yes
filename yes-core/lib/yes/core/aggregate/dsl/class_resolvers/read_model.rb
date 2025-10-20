# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Creates and registers read model classes for aggregates
          #
          # This class resolver generates ActiveRecord-based read model classes
          # that represent the queryable state of aggregates. Each read model class
          # is automatically configured with basic scopes and table name conventions.
          #
          # @example Generated read model class structure
          #   class User < ApplicationRecord
          #     self.table_name = 'users'
          #     scope :by_ids, ->(ids) { where(id: ids) }
          #   end
          class ReadModel < Base
            # Initializes a new read model class resolver
            #
            # @param read_model_name [String] The name of the read model
            # @param context_name [String] The name of the context
            # @param aggregate_name [String] The name of the aggregate
            def initialize(read_model_name, context_name, aggregate_name, draft: false)
              @read_model_name = read_model_name
              @draft = draft
              
              super(context_name, aggregate_name)
            end

            # Creates and registers the read model class in the Yes::Core configuration
            #
            # @return [Class] The found or generated read model class that was registered
            def call
              Yes::Core.configuration.register_read_model_class(
                context_name,
                aggregate_name,
                find_or_generate_class,
                draft: 
              )
            end

            private

            # @return [String] The name of the read model
            attr_reader :read_model_name, :draft

            # @return [Symbol] Returns :read_model as the class type
            def class_type
              :read_model
            end

            # @return [String] The name of the read model class
            def class_name
              read_model_name
            end

            # Generates a new read model class with the required configuration
            #
            # @return [Class] A new read model class inheriting from ApplicationRecord
            def generate_class
              table_name = class_name.tableize

              Class.new(ApplicationRecord) do
                self.table_name = table_name
                scope :by_ids, ->(ids) { where(id: ids) }
              end
            end
          end
        end
      end
    end
  end
end
