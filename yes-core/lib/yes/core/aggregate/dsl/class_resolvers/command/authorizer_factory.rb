# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Factory class for creating appropriate command authorizer resolver
            # based on the aggregate-level authorizer type
            class AuthorizerFactory
              # Creates and returns the appropriate authorizer resolver
              # based on the aggregate's authorizer class type
              #
              # @param command_data [CommandData] Command data with aggregate information
              # @return [SimpleAuthorizer, CerbosAuthorizer, nil] Appropriate authorizer or nil
              def self.create(command_data)
                # Only create command authorizers if there's an aggregate-level authorizer
                aggregate_authorizer_class = command_data.aggregate_class.authorizer_class
                return nil unless aggregate_authorizer_class

                if aggregate_authorizer_class <= Yes::Core::Authorization::CommandCerbosAuthorizer
                  CerbosAuthorizer.new(command_data)
                else
                  SimpleAuthorizer.new(command_data)
                end
              end
            end
          end
        end
      end
    end
  end
end
