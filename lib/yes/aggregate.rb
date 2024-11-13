# frozen_string_literal: true

module Yes
  # The Aggregate class represents a core entity in the eventsourcing system.
  # It provides functionality for managing event sourcing patterns including:
  # - Attribute management with automatic command and event generation
  # - Parent-child aggregate relationships
  # - Read model associations
  # - Context management
  #
  # @example Define an aggregate with attributes
  #   class UserAggregate < Yes::Aggregate
  #     primary_context 'Users'
  #     attribute :email, :email
  #     attribute :name, :string
  #   end
  #
  # @example Define an aggregate with a parent
  #   class ProfileAggregate < Yes::Aggregate
  #     parent :user
  #     attribute :bio, :string
  #   end
  #
  # @author Nico Ritsche
  class Aggregate
    class << self
      attr_reader :_primary_context

      # Defines a parent aggregate.
      #
      # @param name [Symbol] The name of the parent.
      # @param options [Hash] Options for configuring the parent.
      # @return [void]
      def parent(name, options = {})
        parent_aggregates[name] = options
      end

      # Retrieves or initializes the parent_aggregates hash.
      #
      # @return [Hash] A hash containing parent aggregates.
      def parent_aggregates
        @parent_aggregates ||= {}
      end

      # Sets the class name for the read model.
      #
      # @param name [String] The name of the read model class.
      # @return [void]
      def read_model_class_name(name)
        @_read_model_class_name = name
      end

      # Retrieves the read model class.
      # If no explicit class name is set, it will derive the class name from the current namespace.
      #
      # @return [Class, nil] The read model class or nil if the class cannot be found.
      def read_model_class
        (@_read_model_class_name || name.deconstantize.split('::').last).safe_constantize
      end

      # Sets the primary context for the aggregate.
      #
      # @param context [String] The primary context to set.
      # @return [void]
      def primary_context(context)
        @_primary_context = context
      end

      # Defines an attribute on the aggregate which creates corresponding command, event and handler
      #
      # @param name [Symbol] name of the attribute
      # @param type [Symbol] type of the attribute (e.g., :string, :email, :uuid)
      # @param options [Hash] additional options for the attribute
      #
      # @example Define a string attribute
      #   attribute :name, :string
      #
      # @example Define an email attribute with options
      #   attribute :email, :email, validate: true
      def attribute(name, type, **options)
        options = options.merge(
          context: self.name.to_s.split('::').first,
          aggregate: self.name.to_s.split('::').last
        )
        DSL::Attribute.define(name, type, **options)
      end
    end
  end
end
