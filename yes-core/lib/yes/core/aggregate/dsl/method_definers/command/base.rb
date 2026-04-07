# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Command
            # Base class for command method definers that provides common functionality
            # for defining command-related methods on aggregate classes.
            #
            # @abstract Subclass and override {#call} to implement custom command method definition
            class Base
              # Initializes a new command method definer
              #
              # @param command_data [Object] Object containing command configuration
              # @option command_data [Symbol] :name The command name
              # @option command_data [Class] :aggregate_class The target aggregate class where methods will be defined
              def initialize(command_data)
                @name = command_data.name
                @aggregate_class = command_data.aggregate_class
              end

              # Defines the command-related methods on the aggregate class
              #
              # @abstract
              # @raise [NotImplementedError] when called on the base class
              # @return [void]
              def call
                raise NotImplementedError, "#{self.class} must implement #call"
              end

              private

              attr_reader :name, :aggregate_class
            end
          end
        end
      end
    end
  end
end
