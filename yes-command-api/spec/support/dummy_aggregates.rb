# frozen_string_literal: true

# Minimal dummy aggregates for command API request specs.
# V2 commands resolve to Context::Subject::Aggregate (e.g. Dummy::Activity::Aggregate).
module Dummy
  module Activity
    # Handles V2 commands in the Dummy::Activity::Commands namespace.
    # @example Processor resolves Dummy::Activity::Commands::DoSomethingElse::Command
    #   -> Dummy::Activity::Aggregate
    class Aggregate
      # @param _aggregate_id [String] aggregate ID
      # @param draft [Boolean] whether in draft mode
      def initialize(_aggregate_id = nil, draft: false); end

      def method_missing(method_name, cmd_hash = {}, guards: true, **)
        command_class_name = "Dummy::Activity::Commands::#{method_name.to_s.camelize}::Command"
        cmd_class = command_class_name.constantize
        safe_attrs = cmd_hash.symbolize_keys.slice(*cmd_class.schema.map(&:name))
        cmd = cmd_class.new(**safe_attrs)
        Yes::Core::Commands::Response.new(cmd:)
      rescue NameError
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        command_class_name = "Dummy::Activity::Commands::#{method_name.to_s.camelize}::Command"
        command_class_name.constantize
        true
      rescue NameError
        super
      end
    end
  end

  module Company
    # Handles V2 commands in the Dummy::Company::Commands namespace.
    # @example Processor resolves Dummy::Company::Commands::DoSomethingCompounded::Command
    #   -> Dummy::Company::Aggregate
    class Aggregate
      # @param _aggregate_id [String] aggregate ID
      # @param draft [Boolean] whether in draft mode
      def initialize(_aggregate_id = nil, draft: false); end

      def method_missing(method_name, cmd_hash = {}, guards: true, **)
        command_class_name = "Dummy::Company::Commands::#{method_name.to_s.camelize}::Command"
        cmd_class = command_class_name.constantize
        if cmd_class < Yes::Core::Commands::Group
          cmd = cmd_class.new(**cmd_hash.symbolize_keys.except(:origin, :batch_id))
          return Yes::Core::Commands::GroupResponse.new(cmd:)
        end
        safe_attrs = cmd_hash.symbolize_keys.slice(*cmd_class.schema.map(&:name))
        cmd = cmd_class.new(**safe_attrs)
        Yes::Core::Commands::Response.new(cmd:)
      rescue NameError
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        command_class_name = "Dummy::Company::Commands::#{method_name.to_s.camelize}::Command"
        command_class_name.constantize
        true
      rescue NameError
        super
      end
    end
  end
end
