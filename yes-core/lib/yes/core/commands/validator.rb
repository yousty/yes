# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # @abstract Subclass and override {.call} to implement a custom command validator.
      #
      # @example
      #   class MyCommandValidator < Yes::Core::Commands::Validator
      #     def self.call(command)
      #       raise CommandInvalid, 'Name is required' if command.payload[:name].blank?
      #     end
      #   end
      class Validator
        CommandInvalid = Class.new(Yes::Core::Error)

        # Validates the given command. Must be implemented by subclasses.
        #
        # @param command [Yes::Core::Command] command to validate
        # @raise [CommandInvalid] if command is invalid
        # @raise [NotImplementedError] if not overridden
        def self.call(command)
          raise NotImplementedError
        end
      end
    end
  end
end
