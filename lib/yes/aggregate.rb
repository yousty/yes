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
  # @since 0.1.0
  # @author Nico Ritsche
  class Aggregate
    attr_reader :id

    class << self
      # @return [String, nil] The primary context name for this aggregate
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
      # @return [Hash<Symbol, Hash>] A hash containing parent aggregates and their configuration options
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
      # @return [Class, nil] The read model class or nil if the class cannot be found
      # @example
      #   UserAggregate.read_model_class #=> User
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
        @_attributes ||= {}
        @_attributes[name] = type
        options = options.merge(context:, aggregate:)
        DSL::Attribute.define(name, type, self, **options)
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

      # @return [String] The name of the read model
      def read_model_name
        @_read_model_name ||= aggregate.underscore
      end

      attr_reader :_read_model_name, :_read_model_public, :_attributes

      # Sets the read model name for this aggregate
      # @param name [String] The name for the read model
      # @param public [Boolean] Whether the read model should be public via read API
      def read_model(name, public: true)
        @_read_model_name = name
        @_read_model_public = public
      end

      # @return [Boolean] Whether the read model is public
      def read_model_public?
        @_read_model_public.nil? ? true : @_read_model_public
      end

      # @return [Hash] The attributes defined on this aggregate
      def attributes
        @_attributes ||= {}
      end
    end

    # Initializes a new aggregate instance
    # @param id [String, nil] The aggregate ID. If nil, a random UUID will be assigned
    # @return [Yes::Aggregate] A new aggregate instance
    def initialize(id = nil)
      @id = id || SecureRandom.uuid
    end

    private

    # Builds a command instance for the given command name and payload
    #
    # @param command [Symbol] The command name
    # @param payload [Hash] The command payload
    # @return [Object] The instantiated command
    # @raise [RuntimeError] If the command class cannot be found
    def build_command(command, payload)
      command_class = fetch_class(:"change_#{command}", :command)
      command_class.new("#{self.class.aggregate.underscore}_id": id, **payload)
    end

    # Fetches the handler class for a given attribute name
    #
    # @param name [Symbol] The attribute name
    # @return [Class] The handler class
    # @raise [RuntimeError] If the handler class cannot be found
    def fetch_handler_class(name)
      fetch_class(:"change_#{name}", :handler)
    end

    # Fetches a class based on the command name and type
    #
    # @param command [Symbol] The command name
    # @param type [Symbol] The type of class to fetch (:command or :handler)
    # @return [Class] The requested class
    # @raise [RuntimeError] If the requested class cannot be found
    def fetch_class(command, type)
      klass = Yes.configuration.aggregate_class(self.class.context, self.class.aggregate, command, type)
      raise "#{type.to_s.capitalize} class not found for #{command}" unless klass

      klass
    end

    # Updates or creates a read model with the given attributes
    #
    # @param attributes [Hash] The attributes to update the read model with
    # @return [Boolean] Returns true if the record is saved successfully
    # @raise [ActiveRecord::RecordInvalid] If the record is invalid
    def update_read_model(attributes)
      read_model.update!(attributes)
    end

    # Retrieves or creates a read model instance for this aggregate
    #
    # @return [ApplicationRecord] The read model instance associated with this aggregate's ID
    # @example
    #   user_aggregate = UserAggregate.new(1)
    #   user_aggregate.read_model #=> #<User id: 1>
    def read_model
      @read_model ||= read_model_class.find_or_create_by(id:)
    end

    # Retrieves or generates the read model class for this aggregate
    #
    # @return [Class] The read model class
    # @raise [NameError] If the class cannot be found and cannot be generated
    def read_model_class
      @read_model_class ||= begin
        class_name = self.class.read_model_name.classify
        class_name.constantize
      rescue NameError
        generate_read_model_class
      end
    end

    # Dynamically generates a read model class inheriting from ApplicationRecord
    #
    # @return [Class] The generated read model class
    # @raise [NameError] If the class cannot be created
    def generate_read_model_class
      class_name = self.class.read_model_name.classify
      klass = Class.new(ApplicationRecord)
      klass.table_name = self.class.read_model_name.tableize
      Object.const_set(class_name, klass)
    end
  end
end
