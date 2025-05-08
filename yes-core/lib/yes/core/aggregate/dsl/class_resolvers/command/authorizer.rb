# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Base class for command authorizers
            class Authorizer < Base
              # Common methods for all authorizers
              def class_type
                :authorizer
              end

              def class_name
                command_data.name
              end

              # This should be overridden by subclasses
              def generate_class
                raise NotImplementedError, "#{self.class} must implement #generate_class"
              end
            end
          end
        end
      end
    end
  end
end
