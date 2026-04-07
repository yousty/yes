# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Attribute
            # Defines the accessor methods for an aggregate attribute
            class AggregateAccessor < Base
              # Defines reader methods for the aggregate attribute that reads from the read model
              # @return [void]
              def call
                name = @name
                id_name = :"#{name}_id"

                # Define the id accessor
                aggregate_class.define_method(id_name) do
                  read_model.public_send(id_name)
                end

                # Define the aggregate accessor
                aggregate_class.define_method(name) do
                  id = read_model.public_send(id_name)
                  return nil unless id

                  "#{self.class.context}::#{name.to_s.camelize}::Aggregate".constantize.new(id)
                end
              end
            end
          end
        end
      end
    end
  end
end
