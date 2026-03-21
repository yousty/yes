# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # @abstract command authorizer base class. Subclass and override call method to implement
      # a custom authorizer.
      class CommandAuthorizer
        include OpenTelemetry::Trackable

        CommandNotAuthorized = Class.new(Yes::Core::Error)

        class << self
          include OpenTelemetry::Trackable

          # Implement this method to authorize a command. Needs to return true if command is authorized,
          # otherwise raise CommandNotAuthorized.
          # @param command [Yes::Core::Command] command to authorize
          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if command is authorized
          def call(_command, auth_data)
            return true if super_admin?(auth_data)

            current_span&.status = ::OpenTelemetry::Trace::Status.error('Command not authorized')
            raise CommandNotAuthorized
          end
          otl_trackable :call, OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Authorize Command')

          private

          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if user is a super admin
          def super_admin?(auth_data)
            Yes::Core.configuration.super_admin_check.call(auth_data)
          end
        end
      end
    end
  end
end
