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
                  payload = payload.clone if payload.is_a?(Hash)

                  # Extract and remove guards option from options, default to true
                  guards = options.delete(:guards)
                  guards = true if guards.nil?

                  # Extract and remove metadata option from options if present
                  metadata = options.delete(:metadata)

                  # Handle different calling patterns:
                  # 1. command(value) or command(value, guards: false) - shorthand form with single value
                  # 2. command({attr: value}) or command({attr: value}, guards: false) - hash form
                  # 3. command(attr: value) - ALL kwargs are treated as payload (no options)
                  # 4. command() - no arguments (for commands without payload)

                  # If no positional argument was provided but kwargs were given (after removing guards/metadata),
                  # treat all remaining kwargs as payload
                  if payload.nil? && !options.empty?
                    payload = options
                    options = {}
                  elsif payload.nil?
                    payload = {}
                  end

                  # Pass metadata to CommandHandler which will merge it into the event metadata
                  Yes::Core::CommandHandling::CommandHandler.new(self).call(command_name, payload, guards:, metadata:)
                end
              end
            end
          end
        end
      end
    end
  end
end
