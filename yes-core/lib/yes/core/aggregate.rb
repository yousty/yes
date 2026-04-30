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
              subclass.setup_read_model_classes if subclass.read_model_enabled?
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
        # @option options [Boolean] :command (true) When false, skips defining the `assign_<name>` command.
        # @option options [Array<Symbol>] :skip_default_guards ([]) Default guards (e.g. `:not_removed`)
        #   that should not be auto-applied to the generated `assign_<name>` command. See
        #   {.removable} for context on the `:not_removed` auto-block.
        # @yield Block for defining guards and other attribute configurations.
        # @return [void]
        #
        # @example Skip the auto-injected :not_removed guard on a parent's assign command
        #   parent :tenant, skip_default_guards: %i[not_removed]
        def parent(name, **options, &)
          parent_aggregates[name] = options

          attribute name, :aggregate

          return unless options.fetch(:command, true)

          skip_default_guards = options[:skip_default_guards] || []

          command :"assign_#{name}", skip_default_guards: do
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
        # In addition to defining the `:remove` command, `removable` records aggregate-level
        # configuration that the {Yes::Core::CommandHandling::GuardEvaluator} reads at runtime
        # to **auto-block every other command on the aggregate** while the removal attribute is
        # set. The auto-block fires before any registered guard (including the auto-injected
        # `:no_change`), so post-remove mutations consistently raise
        # `GuardEvaluator::InvalidTransition` with the i18n message under
        # `aggregates.<context>.<aggregate>.commands.<command>.guards.not_removed.error`.
        # The `:remove` command itself is exempt and remains gated only by `:no_change`.
        #
        # The auto-block is order-independent: `removable` may be declared before or after the
        # other commands on the aggregate.
        #
        # `attr_name` must correspond to an attribute readable on the aggregate (the macro
        # auto-defines it as `:datetime` when missing).
        #
        # @param attr_name [Symbol] the attribute name to use for marking removal
        # @param not_removed_guards [Boolean] when true (default), every non-`:remove` command on
        #   the aggregate auto-blocks while `attr_name` is set. Pass `false` to disable the
        #   auto-block aggregate-wide; individual commands can still opt in by defining their
        #   own `guard(:not_removed)`.
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
        # @example Disable the :not_removed auto-block aggregate-wide
        #   class UserAggregate < Yes::Core::Aggregate
        #     removable(not_removed_guards: false)
        #   end
        #
        def removable(attr_name: :removed_at, not_removed_guards: true, &)
          attribute attr_name, :datetime unless attributes.key?(attr_name)
          @removable_config = { attr_name:, not_removed_guards: }

          command :remove, skip_default_guards: %i[not_removed] do
            guard(:no_change) { !public_send(attr_name) }
            update_state { method(attr_name).call { Time.current } }
            instance_eval(&) if block_given?
          end
        end

        # Returns the removable configuration for the aggregate, or nil if {.removable} was
        # never called.
        #
        # @return [Hash{Symbol => Object}, nil] hash with two keys when set:
        #   * `:attr_name` [Symbol] — the attribute that marks removal (default `:removed_at`).
        #   * `:not_removed_guards` [Boolean] — whether the auto-block is enabled.
        attr_reader :removable_config

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
        #
        # @example Define a localized attribute
        #   attribute :description, :string, command: true, localized: true
        def attribute(name, type, **options, &)
          raise 'Aggregate attribute definition with command: true is not allowed' if type == :aggregate && options[:command]

          @attributes ||= {}
          @attributes[name] = type

          @attribute_options ||= {}
          @attribute_options[name] = options.slice(:localized)

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
        # @example Skip the auto-injected :not_removed guard for a single command
        #   command :restore, skip_default_guards: %i[not_removed] do
        #     guard(:no_change) { removed_at.present? }
        #     update_state { removed_at { nil } }
        #   end
        #
        # All overloads accept a `skip_default_guards:` keyword argument carrying an array of
        # default-guard symbols (currently only `:not_removed` — see {.removable}) that should
        # not be auto-applied to the command. Defaults to `[]`.
        #
        def command(*args, **kwargs, &)
          skip_default_guards = kwargs.delete(:skip_default_guards) || []
          base_case = Dsl::CommandShortcutExpander.base_case?(*args, **kwargs, &)
          return handle_command_shortcut(*args, skip_default_guards:, **kwargs, &) unless base_case

          name = args.first
          @commands ||= {}
          command_data = Dsl::CommandData.new(name, self, { context:, aggregate:, skip_default_guards: })
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

        # @return [Hash] The attribute options (localized, encrypted, etc.)
        def attribute_options
          @attribute_options ||= {}
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
        def handle_command_shortcut(*, skip_default_guards: [], **, &)
          expanded = Dsl::CommandShortcutExpander.new(*, **, &).call

          expanded.attributes.each do |specification|
            next if attributes.key?(specification.name)

            attribute(specification.name, specification.type, **specification.options)
          end

          expanded.commands.each do |specification|
            command(specification.name, skip_default_guards:, &specification.block)
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

        @command_utilities = Utils::CommandUtils.new(
          context: self.class.context,
          aggregate: self.class.aggregate,
          aggregate_id: @id
        )
      end

      # Reloads the aggregate and its read model
      # @return [Yes::Core::Aggregate] The reloaded aggregate
      def reload
        read_model&.reload

        self
      end

      # Returns the events for the aggregate
      # @return [Enumerator<PgEventstore::Event>] The events for the aggregate
      def events
        PgEventstore.client.read_paginated(
          command_utilities.build_stream(metadata: { draft: draft? }), options: { direction: 'Forwards' }
        )
      end

      # Retrieves the most recent event from the aggregate's event stream
      # @return [PgEventstore::Event, nil] The latest event or nil if no events exist
      def latest_event
        PgEventstore.client.read(
          command_utilities.build_stream(metadata: { draft: draft? }), options: { max_count: 1, direction: :desc }
        ).first
      end

      # Returns the stream revision number of the latest event
      # @return [Integer] The revision number of the latest event in the stream
      # @raise [NoMethodError] If no events exist for this aggregate
      def event_revision
        latest_event.stream_revision
      end

      # Returns a list of commands that can be executed on this aggregate with their associated events
      # @return [Hash<Symbol, Array<Symbol>>] A hash of command names to their event names, sorted alphabetically
      # @example
      #   user_aggregate.commands
      #   # => {
      #   #   approve_documents: [:documents_approved],
      #   #   change_age: [:age_changed],
      #   #   change_email: [:email_changed],
      #   #   change_name: [:name_changed]
      #   # }
      def commands
        mappings = Yes::Core.configuration.command_event_mappings(
          self.class.context,
          self.class.aggregate
        )

        mappings.sort.to_h
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
    end
  end
end
