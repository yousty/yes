# frozen_string_literal: true

module Yes
  module Core
    # Returns the singleton instance of the configuration
    # @return [Yes::Core::Configuration] The configuration instance
    # @example
    #   config = Yes::Core.configuration
    #   config.register_command_class(:user, :create, CreateUserCommand)
    def self.configuration
      @configuration ||= Configuration.new
    end

    # Configures Yes::Core
    # @yield [Yes::Core::Configuration] The configuration instance
    # @example
    #   Yes::Core.configure do |config|
    #     config.aggregate_shortcuts = true
    #   end
    def self.configure
      yield configuration
    end

    class Configuration
      # @return [Boolean] Enable aggregate shortcuts in Rails console (default: false)
      attr_accessor :aggregate_shortcuts

      # @return [#call] A callable that receives auth_data and returns boolean indicating super admin status
      attr_accessor :super_admin_check

      # @return [#call] A callable that receives auth_data and returns a principal data hash for Cerbos
      attr_accessor :cerbos_principal_data_builder

      # @return [String] URL of the Cerbos server
      attr_accessor :cerbos_url

      # @return [Boolean] Whether to include metadata in Cerbos command authorizer responses
      attr_accessor :cerbos_commands_authorizer_include_metadata

      # @return [Boolean] Whether to include metadata in Cerbos read authorizer responses
      attr_accessor :cerbos_read_authorizer_include_metadata

      # @return [Array<String>] Default actions for Cerbos read authorizer
      attr_accessor :cerbos_read_authorizer_actions

      # @return [String] Prefix for Cerbos read authorizer resource ids
      attr_accessor :cerbos_read_authorizer_resource_id_prefix

      # @return [Object] Logger instance
      attr_accessor :logger

      # @return [#call, nil] A callable error reporter responding to #call(error, context:).
      #   When nil, errors are only logged.
      #   Example: ->(error, context:) { Sentry.capture_exception(error, extra: context) }
      attr_accessor :error_reporter

      # @return [Object, nil] Payload store client for resolving large payload references
      attr_accessor :payload_store_client

      # @return [Boolean] Whether to process commands inline (synchronously) or via ActiveJob
      attr_accessor :process_commands_inline

      # @return [Array<Class>] Command notifier classes to instantiate for batch notifications
      attr_accessor :command_notifier_classes

      # @return [Object, nil] OpenTelemetry tracer instance. When nil, all tracing is no-op.
      attr_accessor :otl_tracer

      # @return [String] Anonymous principal ID for Cerbos read authorizer
      attr_accessor :cerbos_read_authorizer_principal_anonymous_id

      # @return [Boolean] Whether to raise on missing handler methods in aggregate state
      attr_accessor :raise_on_missing_handler_method

      # @return [String, nil] URL for subscription heartbeat pings (default: nil, disables heartbeat)
      attr_accessor :subscriptions_heartbeat_url

      # @return [Integer] Interval in seconds between heartbeat pings (default: 30)
      attr_accessor :subscriptions_heartbeat_interval

      # @return [String] Service name for telemetry and identification
      attr_accessor :service_name

      # @return [String] Service version for telemetry
      attr_accessor :service_version

      # @return [#call, nil] Authentication adapter for API controllers.
      #   Must respond to #controller_concern (returns a module to include),
      #   #verify_token(token) and #error_classes (returns array of error classes).
      attr_accessor :auth_adapter

      # Initializes a new configuration instance with nested hashes for class storage.
      def initialize
        @registered_classes = Hash.new do |h, k|
          h[k] = Hash.new { |h2, k2| h2[k2] = {} }
        end
        @aggregate_shortcuts = false
        @super_admin_check = ->(_auth_data) { false }
        @cerbos_principal_data_builder = lambda { |auth_data|
          { id: auth_data[:identity_id], roles: [], attr: {} }
        }
        @cerbos_url = ENV.fetch('CERBOS_URL', nil)
        @cerbos_commands_authorizer_include_metadata = false
        @cerbos_read_authorizer_include_metadata = false
        @cerbos_read_authorizer_actions = %w[read]
        @cerbos_read_authorizer_resource_id_prefix = 'read-'
        @cerbos_read_authorizer_principal_anonymous_id = 'anonymous'
        @logger = nil
        @error_reporter = nil
        @payload_store_client = nil
        @process_commands_inline = true
        @command_notifier_classes = []
        @otl_tracer = nil
        @raise_on_missing_handler_method = defined?(Rails) ? Rails.env.local? : false
        @subscriptions_heartbeat_url = nil
        @subscriptions_heartbeat_interval = 30
        @service_name = ENV.fetch('SERVICE_NAME', nil)
        @service_version = ENV.fetch('APP_VERSION', '')
        @auth_adapter = nil
      end

      # Register a class for a specific aggregate and type
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param action_name [Symbol, String] The name of the command/event
      # @param type [Symbol] The type (:command, :event, or :guard_evaluator)
      # @param klass [Class] The class to register
      # @example Register a command class
      #   register_aggregate_class(:authentication, :user, :create, :command, CreateUserCommand)
      def register_aggregate_class(context_name, aggregate_name, action_name, type, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][type][action_name] = klass
      end

      # Register a read model class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param klass [Class] The class to register
      # @example
      #   register_read_model_class(:authentication, :user, UserReadModel)
      def register_read_model_class(context_name, aggregate_name, klass, draft: false)
        key = [context_name, aggregate_name]
        read_model_key = draft ? :draft_read_model : :read_model
        @registered_classes[key][read_model_key] = klass
      end

      # Register a read model filter class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param klass [Class] The class to register
      # @example
      #   register_read_model_filter_class(:authentication, :user, UserReadModelFilter)
      def register_read_model_filter_class(context_name, aggregate_name, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][:read_model_filter] = klass
      end

      # Register a command class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param klass [Class] The class to register
      # @example
      #   register_command_class(:authentication, :user, :create, CreateUserCommand)
      def register_command_class(context_name, aggregate_name, command_name, klass)
        register_aggregate_class(context_name, aggregate_name, command_name, :command, klass)
      end

      # Register an event class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param event_name [Symbol, String] The name of the event
      # @param klass [Class] The class to register
      # @example
      #   register_event_class(:authentication, :user, :created, UserCreatedEvent)
      def register_event_class(context_name, aggregate_name, event_name, klass)
        register_aggregate_class(context_name, aggregate_name, event_name, :event, klass)
      end

      # Register a guard evaluator class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param klass [Class] The class to register
      # @example
      #   register_guard_evaluator_class(:authentication, :user, :create, CreateUserGuardEvaluator)
      def register_guard_evaluator_class(context_name, aggregate_name, command_name, klass)
        register_aggregate_class(context_name, aggregate_name, command_name, :guard_evaluator, klass)
      end

      # Register an aggregate authorizer class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param klass [Class] The authorizer class to register
      # @example
      #   register_aggregate_authorizer_class(:authentication, :user, UserAuthorizer)
      def register_aggregate_authorizer_class(context_name, aggregate_name, klass)
        key = [context_name, aggregate_name]
        @registered_classes[key][:aggregate_authorizer] = klass
      end

      # Register a command authorizer class for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param klass [Class] The authorizer class to register
      # @example
      #   register_command_authorizer_class(:sales, :user, :create, CreateUserAuthorizer)
      def register_command_authorizer_class(context_name, aggregate_name, command_name, klass)
        register_aggregate_class(context_name, aggregate_name, command_name, :authorizer, klass)
      end

      # Register the event(s) associated with a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @param event_names [Array<Symbol, String>] An array of event names
      # @example
      #   register_command_events(:authentication, :user, :create, [:user_created, :welcome_email_sent])
      def register_command_events(context_name, aggregate_name, command_name, event_names)
        key = [context_name, aggregate_name]
        mappings = @registered_classes[key][:command_event_mappings] ||= {}
        mappings[command_name] = event_names
      end

      # Retrieve all command-to-event mappings for a specific aggregate
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @return [Hash] A hash where keys are command names and values are arrays of event names
      # @example
      #   mappings = command_event_mappings(:authentication, :user)
      def command_event_mappings(context_name, aggregate_name)
        key = [context_name, aggregate_name]
        @registered_classes[key][:command_event_mappings] || {}
      end

      # Retrieve the event names associated with a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @return [Array<Symbol, String>] An array of event names associated with the command, or an empty array if none
      # @example
      #   event_names = command_event_mapping(:authentication, :user, :create)
      def command_event_mapping(context_name, aggregate_name, command_name)
        command_event_mappings(context_name, aggregate_name)[command_name] || []
      end

      # Retrieve the actual event classes associated with a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @return [Array<Class>] An array of event classes associated with the command
      # @example
      #   event_classes = event_classes_for_command(:authentication, :user, :create)
      def event_classes_for_command(context_name, aggregate_name, command_name)
        command_event_mapping(context_name, aggregate_name, command_name).map do |event_name|
          aggregate_class(context_name, aggregate_name, event_name, :event)
        end
      end

      # Retrieve a registered class for a given aggregate, action, and type
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param action_name [Symbol, String, nil] The name of the action (command/event), nil for read_model types
      # @param type [Symbol] The type of the class (:command, :event, :guard_evaluator, :read_model, :draft_read_model)
      # @return [Class, nil] The registered class or nil if not found
      # @example Get a command class
      #   command_class = aggregate_class(:authentication, :user, :create, :command)
      # @example Get a read model class
      #   read_model_class = aggregate_class(:authentication, :user, nil, :read_model)
      def aggregate_class(context_name, aggregate_name, action_name, type)
        if action_name.nil?
          @registered_classes.dig([context_name, aggregate_name], type)
        else
          @registered_classes.dig([context_name, aggregate_name], type, action_name)
        end
      end

      # List all registered classes for a specific aggregate in a context
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @return [Hash] A hash of registered classes grouped by type
      # @example
      #   classes = list_aggregate_classes("Authentication", "User)
      def list_aggregate_classes(context_name, aggregate_name)
        @registered_classes[[context_name, aggregate_name]]
      end

      # Retrieve a guard evaluator class for a specific command
      # @param context_name [Symbol, String] The context for the aggregate
      # @param aggregate_name [Symbol, String] The name of the aggregate
      # @param command_name [Symbol, String] The name of the command
      # @return [Class, nil] The registered guard evaluator class or nil if not found
      # @example
      #   evaluator = guard_evaluator_class(:authentication, :user, :create)
      def guard_evaluator_class(context_name, aggregate_name, command_name)
        aggregate_class(context_name, aggregate_name, command_name.to_s.underscore.to_sym, :guard_evaluator)
      end

      # List all registered classes across all aggregates and contexts
      # @return [Hash] A complete hash of all registered classes
      # @example
      #   all_classes = list_all_registered_classes
      #   # Returns:
      #   # {
      #   #   [:authentication, :user] => {
      #   #     command: { create: CreateUserCommand },
      #   #     event: { created: UserCreatedEvent },
      #   #     guard_evaluator: { create: CreateUserGuardEvaluator }
      #   #   }
      #   # }
      def list_all_registered_classes
        @registered_classes
      end

      # Get all read model class names from registered aggregates
      # @return [Array<String>] Array of read model class names
      # @example
      #   read_model_classes = all_read_model_class_names
      #   # Returns: ["UserReadModel", "UserChangesReadModel", "ProfileReadModel", ...]
      def all_read_model_class_names
        list_all_registered_classes.keys.flat_map do |context_aggregate|
          context_name, aggregate_name = context_aggregate
          aggregate_class_name = "#{context_name.to_s.camelize}::#{aggregate_name.to_s.camelize}::Aggregate"

          begin
            aggregate_class = aggregate_class_name.constantize
            models = []

            # Add main read model if it exists
            models << aggregate_class.read_model_name.camelize.to_s if aggregate_class.respond_to?(:read_model_name) && aggregate_class.read_model_name

            # Add changes read model if aggregate is draftable
            models << aggregate_class.changes_read_model_name.camelize.to_s if aggregate_class.respond_to?(:changes_read_model_name) && aggregate_class.changes_read_model_name

            models
          rescue NameError
            # Skip if aggregate class doesn't exist
            []
          end
        end.compact.uniq
      end

      # Get all read model classes (constantized)
      # @return [Array<Class>] Array of read model classes
      # @example
      #   read_model_classes = all_read_model_classes
      #   # Returns: [UserReadModel, UserChangesReadModel, ProfileReadModel, ...]
      def all_read_model_classes
        all_read_model_class_names.filter_map do |class_name|
          class_name.constantize
        rescue NameError
          nil
        end
      end

      # Get all read model classes with their associated aggregate classes
      # @return [Array<Hash>] Array of hashes with read_model_class, aggregate_class, and is_draft flag
      # @example
      #   mappings = all_read_models_with_aggregate_classes
      #   # Returns: [
      #   #   { read_model_class: UserReadModel, aggregate_class: User::Aggregate, is_draft: false },
      #   #   { read_model_class: UserChangesReadModel, aggregate_class: User::Aggregate, is_draft: true }
      #   # ]
      def all_read_models_with_aggregate_classes
        list_all_registered_classes.keys.flat_map do |context_aggregate|
          context_name, aggregate_name = context_aggregate
          aggregate_class_name = "#{context_name.to_s.camelize}::#{aggregate_name.to_s.camelize}::Aggregate"

          begin
            aggregate_class = aggregate_class_name.constantize
            models = []

            # Main read model (not draft)
            if aggregate_class.respond_to?(:read_model_name) && aggregate_class.read_model_name
              begin
                read_model_class = aggregate_class.read_model_name.camelize.constantize
                models << {
                  read_model_class: read_model_class,
                  aggregate_class: aggregate_class,
                  is_draft: false
                }
              rescue NameError
                # Skip if read model class doesn't exist
              end
            end

            # Changes read model (draft)
            if aggregate_class.respond_to?(:changes_read_model_name) && aggregate_class.changes_read_model_name
              begin
                changes_model_class = aggregate_class.changes_read_model_name.camelize.constantize
                models << {
                  read_model_class: changes_model_class,
                  aggregate_class: aggregate_class,
                  is_draft: true
                }
              rescue NameError
                # Skip if changes read model class doesn't exist
              end
            end

            models
          rescue NameError
            # Skip if aggregate class doesn't exist
            []
          end
        end.compact
      end

      # Get all read model table names
      # @return [Array<String>] Array of read model table names
      # @example
      #   table_names = all_read_model_table_names
      #   # Returns: ["user_read_models", "user_changes_read_models", "profile_read_models", ...]
      def all_read_model_table_names
        all_read_model_classes.map(&:table_name).uniq
      end
    end
  end
end
