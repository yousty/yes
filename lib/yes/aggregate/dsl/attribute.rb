# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      # Handles the definition and generation of attribute-related classes for aggregates
      # This includes commands, events, and handlers for attribute changes.
      #
      # @example
      #   Attribute.define(:name, :string, validate: true)
      #
      class Attribute
        # Defines a new attribute and generates all necessary classes
        #
        # @param name [Symbol] The name of the attribute
        # @param type [Symbol] The type of the attribute (e.g., :string, :integer)
        # @param aggregate_class [Class] The aggregate class to define the attribute on
        # @param options [Hash] Additional options for the attribute
        # @option options [String] :context The context name for the attribute
        # @option options [String] :aggregate The aggregate name
        # @return [void]
        def self.define(name, type, aggregate_class, **options)
          new(name, type, aggregate_class, options).define
        end

        # @param name [Symbol] The name of the attribute
        # @param type [Symbol] The type of the attribute
        # @param aggregate_class [Class] The aggregate class to define the attribute on
        # @param options [Hash] Additional options for the attribute
        # @option options [String] :context The context name for the attribute
        # @option options [String] :aggregate The aggregate name
        def initialize(name, type, aggregate_class, options)
          @name = name
          @type = type
          @aggregate_class = aggregate_class
          @command_name = :"change_#{name}"
          @event_name = :"#{name}_changed"
          @context_name = options.delete(:context)
          @aggregate_name = options.delete(:aggregate)
        end

        # Generates and registers all necessary classes for the attribute
        # This includes a command class, event class, and handler class
        #
        # @return [void]
        def define
          ClassResolvers::Command.new(self).call
          ClassResolvers::Event.new(self).call
          ClassResolvers::Handler.new(self).call
          AttributeMethodDefiners::ChangeCommand.new(name, aggregate_class).call
          AttributeMethodDefiners::CanChangeCommand.new(name, aggregate_class).call
          AttributeMethodDefiners::Accessor.new(name, aggregate_class).call
        end

        private

        attr_reader :name, :type, :command_name, :event_name, :context_name, :aggregate_name, :aggregate_class
      end
    end
  end
end
