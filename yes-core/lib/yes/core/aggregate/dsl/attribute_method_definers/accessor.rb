# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeMethodDefiners
          # Defines the accessor method for an attribute
          class Accessor < Base
            # Defines a reader method for the attribute that reads from the read model
            # @return [void]
            def call
              name = @name

              aggregate_class.define_method(name) do
                read_model.public_send(name)
              end
            end
          end
        end
      end
    end
  end
end
