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

              # Adds a `call` instance method that executes the user-provided block
              #
              # @param klass [Class] the class being generated
              def apply_call_override(klass)
                user_block = command_data.authorizer_block

                # helper accessors for DSL convenience
                klass.define_method(:command)    { @_cmd }
                klass.define_method(:auth_data)  { @_auth }

                klass.define_method(:call) do |cmd, auth|
                  @_cmd = cmd
                  @_auth = auth
                  begin
                    instance_exec(&user_block)
                  ensure
                    remove_instance_variable(:@_cmd)  if instance_variable_defined?(:@_cmd)
                    remove_instance_variable(:@_auth) if instance_variable_defined?(:@_auth)
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
