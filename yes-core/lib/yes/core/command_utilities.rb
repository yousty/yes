# frozen_string_literal: true

module Yes
  module Core
    # Handles command and handler class operations for aggregates
    #
    # @since 0.1.0
    # @api private
    class CommandUtilities
      # @param context [String] The context namespace
      # @param aggregate [String] The aggregate name
      # @param aggregate_id [String] The ID of the aggregate
      def initialize(context:, aggregate:, aggregate_id:)
        @context = context
        @aggregate = aggregate
        @aggregate_id = aggregate_id
      end

      # Builds a command instance for the given command name and payload
      #
      # @param command [Symbol] The command name
      # @param payload [Hash] The command payload
      # @return [Object] The instantiated command
      # @raise [RuntimeError] If the command class cannot be found
      def build_command(command, payload)
        command_class = fetch_class(:"change_#{command}", :command)
        command_class.new("#{@aggregate.underscore}_id": @aggregate_id, **payload)
      end

      # Fetches the handler class for a given attribute name
      #
      # @param name [Symbol] The attribute name
      # @return [Class] The handler class
      # @raise [RuntimeError] If the handler class cannot be found
      def fetch_handler_class(name)
        fetch_class(:"change_#{name}", :handler)
      end

      private

      # Fetches a class based on the command name and type
      #
      # @param command [Symbol] The command name
      # @param type [Symbol] The type of class to fetch (:command or :handler)
      # @return [Class] The requested class
      # @raise [RuntimeError] If the requested class cannot be found
      def fetch_class(command, type)
        klass = Yes::Core.configuration.aggregate_class(@context, @aggregate, command, type)
        raise "#{type.to_s.capitalize} class not found for #{command}" unless klass

        klass
      end
    end
  end
end
