# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Command resolver for simple non-Cerbos authorizers
            class SimpleAuthorizer < Authorizer
              private

              # Generates a simple authorizer class with a call method
              #
              # @return [Class] The generated authorizer class
              def generate_class
                klass = Class.new(command_data.aggregate_class.authorizer_class)

                # Only add call method if we have a block
                apply_call_override(klass) if command_data.authorizer_block

                klass
              end

              # Adds a `call` class method that executes the user-provided block
              #
              # @param klass [Class] the class being generated
              def apply_call_override(klass)
                user_block = command_data.authorizer_block

                klass.define_singleton_method(:call) do |cmd, auth|
                  @_cmd = cmd
                  @_auth = auth
                  define_singleton_method(:command) { @_cmd }
                  define_singleton_method(:auth_data) { @_auth }
                  begin
                    instance_exec(&user_block)
                  ensure
                    @_cmd = nil
                    @_auth = nil
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
