# frozen_string_literal: true

module Yes
  module Core
    # The Aggregate class represents a core entity in the eventsourcing system.
    # It provides functionality for managing event sourcing patterns including:
    # - Attribute management with automatic command and event generation
    # - Parent-child aggregate relationships
    # - Read model associations
    # - Context management
    #
    # @example Define an aggregate with attributes
    #   class UserAggregate < Yes::Core::Aggregate
    #     primary_context 'Users'
    #     attribute :email, :email
    #     attribute :name, :string
    #   end
    #
    # @example Define an aggregate with a parent
    #   class ProfileAggregate < Yes::Core::Aggregate
    #     parent :user
    #     attribute :bio, :string
    #   end
    #
    # @since 0.1.0
    # @author Nico Ritsche
    class Aggregate
      attr_reader :id, :command_utilities

      private :command_utilities

      include HasReadModel
      include CommandHandling

      class << self
        # @return [String, nil] The primary context name for this aggregate
        attr_reader :_primary_context

        # Hook that runs when a class inherits from Aggregate
        # @param subclass [Class] The class inheriting from Aggregate
        # @return [void]
        def inherited(subclass)
          super

          # Add an "end of definition" hook using at_exit
          # Setting up read model classes is done here, because it needs to be done after
          # the class definition is complete.
          TracePoint.new(:end) do |tp|
            if tp.self == subclass
              subclass.setup_read_model_classes
              tp.disable
            end
          end.enable
        end

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
        # @return [Hash<Symbol, Hash>] A hash containing parent aggregates and their configuration options
        def parent_aggregates
          @parent_aggregates ||= {}
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
          @attributes ||= {}
          @attributes[name] = type
          options = options.merge(context:, aggregate:)
          Dsl::AttributeDefiner.new(
            Dsl::AttributeData.new(name, type, self, options)
          ).call
        end

        # Returns the context namespace for the aggregate
        #
        # @return [String] The context namespace
        # @example
        #   Users::User::Aggregate.context #=> "Users"
        def context
          name.to_s.split('::').first
        end

        # Returns the aggregate name without namespace and "Aggregate" suffix
        #
        # @return [String] The aggregate name
        # @example
        #   Users::User::Aggregate.aggregate #=> "User"
        def aggregate
          name.to_s.split('::')[-2]
        end

        # @return [Hash] The attributes defined on this aggregate
        def attributes
          @attributes ||= {}
        end
      end

      # Initializes a new aggregate instance
      # @param id [String] The aggregate ID.
      # @return [Yes::Core::Aggregate] A new aggregate instance
      def initialize(id = SecureRandom.uuid)
        @id = id
        @command_utilities = CommandUtilities.new(
          context: self.class.context,
          aggregate: self.class.aggregate,
          aggregate_id: @id
        )
      end
    end
  end
end
