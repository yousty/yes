# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Helpers
        # Helper for V2 folder structure commands where the last segment is "Command"
        # (e.g. Context::Subject::Commands::DoSomething::Command).
        class V2 < Helper
          # Returns the underscored command name.
          #
          # @return [String] the command name
          def command_name
            inflector.underscore(splitted_command(cmd)[-2])
          end

          # Returns the aggregate class name (always "Aggregate" in V2).
          #
          # @return [String] the aggregate class name
          def aggregate_classname
            'Aggregate'
          end

          # Returns the aggregate module name.
          #
          # @return [String] the aggregate module name
          def aggregate_module
            splitted_command(cmd)[-4]
          end
          alias_method :subject, :aggregate_module

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

          # Returns the subject ID from the command.
          #
          # @return [String] the subject/aggregate ID
          def subject_id
            cmd.subject_id
          end
        end
      end
    end
  end
end
