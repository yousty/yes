# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Helpers
        # Helper for V1 folder structure commands where the command class name
        # is the last segment (e.g. Context::Commands::Subject::DoSomething).
        class V1 < Helper
          # Returns the underscored command name.
          #
          # @return [String] the command name
          def command_name
            inflector.underscore(splitted_command(cmd).last)
          end

          # Returns the aggregate class name.
          #
          # @return [String] the aggregate class name
          def aggregate_classname
            splitted_command(cmd)[-2]
          end

          # Returns the aggregate module name.
          #
          # @return [String] the aggregate module name
          def aggregate_module
            splitted_command(cmd)[-2]
          end
          alias_method :subject, :aggregate_module

          # Returns the fully qualified authorizer class name.
          #
          # @return [String] the authorizer class name
          def authorizer_classname
            "#{cmd.class}Authorizer"
          end

          # Returns the fully qualified validator class name.
          #
          # @return [String] the validator class name
          def validator_classname
            "#{cmd.class}Validator"
          end

          # Returns the aggregate class constant.
          #
          # @return [Class] the aggregate class
          def aggregate_class
            inflector.constantize(
              [
                command_context,
                command_version,
                aggregate_classname
              ].compact.join('::')
            )
          end

          # Returns the subject ID from the command.
          #
          # @return [String] the subject/aggregate ID
          def subject_id
            cmd.aggregate_id
          end
        end
      end
    end
  end
end
