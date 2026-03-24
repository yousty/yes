# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Provides naming resolution helpers for commands following the V2 folder structure
      # (e.g. Context::Subject::Commands::DoSomething::Command).
      #
      # @example
      #   helper = Yes::Core::Commands::Helper.new(command)
      #   helper.command_name
      class Helper
        AGGREGATE_CLASSNAME = 'Aggregate'
        VERSION_REGEXP = /::(?<version>V\d+)::/

        attr_reader :inflector, :cmd
        private :inflector, :cmd

        delegate :splitted_command, to: :class

        class << self
          # Splits the command class name into module parts.
          #
          # @param cmd [Yes::Core::Command] the command instance
          # @return [Array<String>] the split class name parts
          def splitted_command(cmd)
            cmd.class.to_s.split('::')
          end
        end

        # @param cmd [Yes::Core::Command] the command instance
        def initialize(cmd)
          @inflector = Dry::Inflector.new
          @cmd = cmd
        end

        # Returns the top-level context module of the command.
        #
        # @return [String] the command context
        def command_context
          splitted_command(cmd).first
        end
        alias context command_context

        # Returns the locale for the command.
        #
        # @return [Symbol] the locale
        def command_locale
          cmd.respond_to?(:locale) ? cmd.locale : I18n.locale
        end
        alias locale command_locale

        # Extracts the version from the command class name.
        #
        # @return [String, nil] the version string (e.g. "V1") or nil
        def command_version
          VERSION_REGEXP.match(cmd.class.to_s)&.[](:version)
        end

        # Returns the event payload with stringified keys.
        #
        # @return [Hash] the deep stringified event payload
        def event_payload
          cmd.payload.deep_stringify_keys
        end

        # Returns the underscored command name.
        #
        # @return [String] the command name
        def command_name
          inflector.underscore(splitted_command(cmd)[-2])
        end

        # Returns the aggregate class name.
        #
        # @return [String] the aggregate class name
        def aggregate_classname
          AGGREGATE_CLASSNAME
        end

        # Returns the aggregate module name.
        #
        # @return [String] the aggregate module name
        def aggregate_module
          splitted_command(cmd)[-4]
        end
        alias subject aggregate_module

        # Returns the fully qualified authorizer class name.
        #
        # @return [String] the authorizer class name
        def authorizer_classname
          spl = splitted_command(cmd)
          spl[0] == 'CommandGroups' ? "#{spl[0..1].join('::')}::Authorizer" : "#{spl[0..3].join('::')}::Authorizer"
        end

        # Returns the fully qualified validator class name.
        #
        # @return [String] the validator class name
        def validator_classname
          spl = splitted_command(cmd)
          spl[0] == 'CommandGroups' ? "#{spl[0..1].join('::')}::Validator" : "#{spl[0..3].join('::')}::Validator"
        end

        # Returns the aggregate class constant.
        #
        # @return [Class] the aggregate class
        def aggregate_class
          inflector.constantize(
            [
              command_context,
              command_version,
              aggregate_module,
              aggregate_classname
            ].compact.join('::')
          )
        end

        # Returns the aggregate ID from the command.
        #
        # @return [String] the aggregate ID
        def aggregate_id
          cmd.aggregate_id
        end
      end
    end
  end
end
