# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Factory class that determines the correct command helper variant
      # based on the command's folder structure (V1 or V2).
      #
      # @example
      #   helper = Yes::Core::Commands::Helper.new(command)
      #   helper.command_name
      class Helper
        VERSION_REGEXP = /::(?<version>V\d+)::/.freeze

        attr_reader :inflector, :cmd
        private :inflector, :cmd

        delegate :splitted_command, :folder_structure_v2?, to: :class

        class << self
          # Creates the appropriate helper variant based on folder structure.
          #
          # @param cmd [Yes::Core::Command] the command instance
          # @return [Helpers::V1, Helpers::V2] the helper instance
          def new(cmd)
            return super unless self == Helper

            helper_variant(cmd)
          end

          # Determines if the command uses V2 folder structure.
          #
          # @param cmd [Yes::Core::Command] the command instance
          # @return [Boolean] true if V2 folder structure
          def folder_structure_v2?(cmd)
            splitted_command(cmd).last == 'Command'
          end

          # Returns the appropriate helper variant for the command.
          #
          # @param cmd [Yes::Core::Command] the command instance
          # @return [Helpers::V1, Helpers::V2] the helper instance
          def helper_variant(cmd)
            return Helpers::V2.new(cmd) if folder_structure_v2?(cmd)

            Helpers::V1.new(cmd)
          end

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
        alias_method :context, :command_context

        # Returns the locale for the command.
        #
        # @return [Symbol] the locale
        def command_locale
          cmd.respond_to?(:locale) ? cmd.locale : I18n.locale
        end
        alias_method :locale, :command_locale

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
      end
    end
  end
end
