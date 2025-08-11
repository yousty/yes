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
    #     parent :user do
    #       guard(:user_exists) { payload.user.present? }
    #       guard(:not_removed) { trashed_at.blank? }
    #     end
    #     attribute :bio, :string
    #   end
    #
    # @example Define an aggregate with a command
    #   class CompanyAggregate < Yes::Core::Aggregate
    #     primary_context 'Companies'
    #
    #     command :assign_user do
    #       payload user_id: :uuid
    #
    #       guard :user_already_assigned do
    #         user_id.present?
    #       end
    #     end
    #   end
    #
    # @since 0.1.0
    # @author Nico Ritsche
    class Aggregate
      attr_reader :id, :command_utilities, :draft

      private :command_utilities, :draft

      include HasReadModel
      include Draftable
      include HasAuthorizer
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
              subclass.setup_authorizer_classes
              tp.disable
            end
          end.enable
        end

        # Defines a parent aggregate and automatically registers a corresponding Assign command
        # together with a corresponding attribute.
        #
        # @param name [Symbol] The name of the parent.
        # @param options [Hash] Options for configuring the parent.
        # @yield Block for defining guards and other attribute configurations.
        # @return [void]
        def parent(name, **options, &)
          parent_aggregates[name] = options

          attribute name, :aggregate

          return unless options.fetch(:command, true)

          command :"assign_#{name}" do
            payload "#{name}_id": :uuid

            guard(:no_change) { public_send(:"#{name}_id") != payload.public_send(:"#{name}_id") }

            instance_eval(&) if block_given?
          end
        end

        # Retrieves or initializes the parent_aggregates hash.
        #
        # @return [Hash<Symbol, Hash>] A hash containing parent aggregates and their configuration options
        def parent_aggregates
          @parent_aggregates ||= {}
        end

        # Defines a default removal behavior for the aggregate.
        #
        # @param attr_name [Symbol] the attribute name to use for marking removal
        # @yield Block for defining additional guards and other removal configurations
        # @return [void]
        #
        # @example Define a default removal behavior
        #   class UserAggregate < Yes::Core::Aggregate
        #     removable
        #   end
        #
        # @example Define a removal behavior with additional custom guards
        #   class UserAggregate < Yes::Core::Aggregate
        #     removable do
        #       guard(:exists) { read_model.name.present? }
        #     end
        #   end
        #
        # @example Define a removal behavior with a custom attribute name
        #   class UserAggregate < Yes::Core::Aggregate
        #     removable(attr_name: :deleted_at)
        #   end
        #
        def removable(attr_name: :removed_at, &)
          attribute attr_name, :datetime unless attributes.key?(attr_name)

          command :remove do
            guard(:no_change) { !public_send(attr_name) }
            update_state { method(attr_name).call { Time.current } }
            instance_eval(&) if block_given?
          end
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
        # @yield Block for defining guards and other attribute configurations
        # @yieldreturn [void]
        #
        # @example Define a string attribute (without command)
        #   attribute :name, :string
        #
        # @example Define an aggregate attribute (without command)
        #   attribute :location, :aggregate
        #
        # @example Define an email attribute with command
        #   attribute :email, :email, command: true
        #
        # @example Define an attribute with command and guards
        #   attribute :first_name, :string, command: true do
        #     guard :something do
        #       first_name == 'John'
        #     end
        #   end
        def attribute(name, type, **options, &)
          if type == :aggregate && options[:command]
            raise 'Aggregate attribute definition with command: true is not allowed'
          end

          @attributes ||= {}
          @attributes[name] = type

          options = options.merge(context:, aggregate:)
          Dsl::AttributeDefiner.new(
            Dsl::AttributeData.new(name, type, self, options)
          ).call

          command(:change, name, type, &) if options[:command]
        end

        # Defines a command on the aggregate which creates corresponding command and event classes
        #
        # @overload command(name, &)
        #   @param name [Symbol] name of the command
        #   @yield Block for defining payload, guards, and other command configurations
        #   @yieldreturn [void]
        #
        # @overload command(publish)
        #   @param publish [Symbol] passing :publish as a name will generate published attribute and publish command
        #   @return [void]
        #
        # @overload command(change, attribute, **options)
        #   @param change [Symbol] passing :change as a name will generate a change command and an attribute
        #   @param attribute [Symbol] attribute name
        #   @param options [Hash] additional options for the attribute
        #   @return [void]
        #
        # @overload command(enable, attribute, **options)
        #   @param enable [Symbol] passing :enable or :activate as a name will generate a flag set to true command and an attribute
        #   @param attribute [Symbol] attribute name
        #   @param options [Hash] additional options for the attribute
        #   @return [void]
        #
        # @overload command(toggle_names, attribute)
        #  @param toggle_names [Array<Symbol>] toggle command names to be generated
        #  @param attribute [Symbol] attribute name
        #  @return [void]
        #
        # @example Define a basic command
        #   command :assign_user
        #
        # @example Define a command with custom payload and guards
        #   command :assign_user do
        #     payload user_id: :uuid
        #
        #     guard :user_already_assigned do
        #       user_id.present?
        #     end
        #
        #     event :user_assigned
        #   end
        #
        # @example Define change command and an attribute
        #   command :change, :age, :integer, localized: true
        #
        # @example Define set flag to true command an an attribute
        #   command :activate, :dropout, attribute: :dropout_enabled
        #
        # @example Define set of toggle commands an an attribute
        #   command [:enable, :disable], :dropout
        #
        # @example Define publish command an published attribute
        #   command :publish
        #
        def command(*args, **, &)
          return handle_command_shortcut(*args, **, &) unless Dsl::CommandShortcutExpander.base_case?(*args, **, &)

          name = args.first
          @commands ||= {}
          command_data = Dsl::CommandData.new(name, self, { context:, aggregate: })
          @commands[name] = command_data

          Dsl::CommandDefiner.new(command_data).call(&)
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

        # @return [Hash] The commands defined on this aggregate
        def commands
          @commands ||= {}
        end

        private

        #
        # Takes all parameters passed to command invocation, forwards them to the command shortcut expander
        # and then defines commands and attributes
        #
        # @param [Array<Object>] *args
        # @param [Hash<Object, Object>] **kwargs
        # @param [Proc] &block
        #
        # @return [void]
        #
        def handle_command_shortcut(...)
          expanded = Dsl::CommandShortcutExpander.new(...).call

          expanded.attributes.each do |specification|
            next if attributes.key?(specification.name)

            attribute(specification.name, specification.type, **specification.options)
          end

          expanded.commands.each do |specification|
            command(specification.name, &specification.block)
          end
        end
      end

      # Initializes a new aggregate instance
      # @param id [String] The aggregate ID (optional, defaults to SecureRandom.uuid)
      # @param draft [Boolean] Whether this instance is being edited as a draft (default: false)
      # @return [Yes::Core::Aggregate] A new aggregate instance
      #
      # @example Backwards compatibility - single ID parameter
      #   Aggregate.new(some_id)
      #
      # @example With draft as keyword argument
      #   Aggregate.new(draft: true)
      #
      # @example With positional id and draft keyword
      #   Aggregate.new(some_id, draft: true)
      #
      def initialize(id = SecureRandom.uuid, draft: false)
        validate_draft_initialization(draft)

        @id = id
        @draft = draft

        @command_utilities = build_command_utilities
      end

      # Reloads the aggregate and its read model
      # @return [Yes::Core::Aggregate] The reloaded aggregate
      def reload
        read_model.reload

        self
      end

      # Returns the events for the aggregate
      # @return [Enumerator<PgEventstore::Event>] The events for the aggregate
      def events
        PgEventstore.client.read_paginated(command_utilities.build_stream, options: { direction: 'Forwards' })
      end

      private

      # Validates that draft initialization is only allowed for draftable aggregates
      #
      # @param draft [Boolean] Whether the aggregate is being initialized as a draft
      # @raise [ArgumentError] If draft is true but aggregate is not draftable
      # @return [void]
      def validate_draft_initialization(draft)
        return unless draft && !self.class.draftable?

        raise ArgumentError, "#{self.class.name} is not draftable. Add 'draftable' to the class definition."
      end

      # Builds command utilities with appropriate context and aggregate based on draft status
      #
      # @return [Utils::CommandUtils] The command utilities instance
      def build_command_utilities
        context = @draft && self.class.draftable? ? self.class.draft_context : self.class.context
        aggregate = @draft && self.class.draftable? ? self.class.draft_aggregate : self.class.aggregate

        Utils::CommandUtils.new(
          context:,
          aggregate:,
          aggregate_id: @id
        )
      end
    end
  end
end
