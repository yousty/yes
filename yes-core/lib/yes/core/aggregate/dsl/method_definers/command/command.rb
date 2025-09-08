# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Command
            # Defines a command method on the aggregate class
            class Command < Base
              # @return [void]
              def call
                command_name = @name

                aggregate_class.define_method(command_name) do |payload = nil, **options|
                  # Extract guards option, default to true
                  guards = options.fetch(:guards, true)
                  
                  # Handle different calling patterns:
                  # 1. command(value) or command(value, guards: false) - shorthand form with single value
                  # 2. command({attr: value}) or command({attr: value}, guards: false) - hash form
                  # 3. command(attr: value) - ALL kwargs are treated as payload (no options)
                  # 4. command() - no arguments (for commands without payload)
                  
                  # If no positional argument was provided but kwargs were given,
                  # treat all kwargs as payload (options must be passed with explicit hash)
                  if payload.nil? && !options.empty? && !options.key?(:guards)
                    payload = options
                    options = {}
                    guards = true
                  elsif payload.nil?
                    payload = {}
                  end
                  
                  execute_command_and_update_state(command_name, payload, guards:)
                end
              end
            end
          end
        end
      end
    end
  end
end
