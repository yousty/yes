# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # @abstract command Cerbos authorizer base class.
      class CommandCerbosAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        NEW_RESOURCE_ID = 'new'

        class << self
          include OpenTelemetry::Trackable

          # @param command [Yes::Core::Command] command to authorize
          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if command is authorized
          # @raise [CommandNotAuthorized] if command is not authorized
          def call(command, auth_data)
            singleton_class.current_span&.add_attributes({ 'command' => command.to_json })
            check_principal_id_present(auth_data)

            resource = load_resource(command)

            decision = authorize(command, resource, auth_data)
            singleton_class.current_span&.add_event('Cerbos Decision', attributes: { 'decision' => decision.to_json })
            return true if decision.allow_all?

            raise_command_unauthorized_error!(decision)
          end
          otl_trackable :call, OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Cerbos Authorize Command')

          private

          # @param decision [Cerbos::Output::CheckResources::Result]
          # raise [NotAuthorized]
          def raise_command_unauthorized_error!(decision)
            msg = 'You are not allowed to execute this command'
            singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error(msg)

            raise self::CommandNotAuthorized.new(msg, extra: { decision: decision.outputs.map(&:value) })
          end

          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if user_uuid is present in auth_data
          # @raise [CommandNotAuthorized] if user_uuid is not present in auth_data
          def check_principal_id_present(auth_data)
            return true if principal_id(auth_data)

            msg = 'Missing identity id in JWT token auth_data'
            singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error(msg)
            raise self::CommandNotAuthorized, msg
          end

          # @param command [Yes::Core::Command] command to authorize
          # @return [ActiveRecord::Base] resource to authorize
          # @raise [StandardError] if RESOURCE[:name] or RESOURCE[:read_model] is not defined
          def load_resource(command)
            unless defined?(self::RESOURCE) && self::RESOURCE[:name] && self::RESOURCE[:read_model]
              message =
                'Your CommandCerbosAuthorizer subclass needs to define RESOURCE[:name] and RESOURCE[:read_model] constant'
              raise StandardError, message
            end

            self::RESOURCE[:read_model].find_by(id: command.send("#{self::RESOURCE[:name]}_id"))
          end

          # @return [Cerbos::Client] Cerbos client
          def cerbos_client
            Cerbos::Client.new(
              Yes::Core.configuration.cerbos_url,
              tls: false
            )
          end

          def authorize(...)
            cerbos_client.check_resource(**cerbos_payload(...))
          end

          # @param command [Yes::Core::Command] command to authorize
          # @param resource [ActiveRecord::Base] resource to authorize
          # @param auth_data [Hash] authorization data
          # @return [Hash] payload for Cerbos check_resource
          def cerbos_payload(command, resource, auth_data)
            {
              principal: principal_data(auth_data).deep_merge(attributes: { command_payload: command.payload }),
              resource: resource_data(resource, command),
              actions: actions(command),
              include_metadata: Yes::Core.configuration.cerbos_commands_authorizer_include_metadata
            }.deep_symbolize_keys.tap { singleton_class.current_span&.set_attribute('cerbos_payload', _1.to_json) }
          end

          # @param resource [ActiveRecord::Base] resource to authorize
          # @param command [Yes::Core::Command] command to authorize
          # @return [Hash] resource data for Cerbos check_resource
          def resource_data(resource, command)
            {
              kind: resource_kind(resource),
              scope: scope(command),
              id: resource_id(resource),
              attributes: resource_attributes(resource, command)
            }
          end

          # @param resource [ActiveRecord::Base] resource to authorize
          # @return [String] resource kind for Cerbos check_resource
          def resource_kind(resource)
            resource&.id ? self::RESOURCE[:name] : new_resource_id
          end

          # @param resource [ActiveRecord::Base] resource to authorize
          # @return [String] resource id for Cerbos check_resource
          def resource_id(resource)
            resource&.id || new_resource_id
          end

          # @param resource [ActiveRecord::Base] resource to authorize
          # @param command [Yes::Core::Command] command to authorize
          # @return [Hash] resource attributes for Cerbos check_resource
          def resource_attributes(resource, _command)
            resource&.try(:auth_attributes)&.as_json || {}
          end

          # @param auth_data [Hash] authorization data
          # @return [Hash] principal data for Cerbos check_resource
          def principal_data(auth_data)
            Yes::Core.configuration.cerbos_principal_data_builder.call(
              auth_data.with_indifferent_access
            )
          end

          # @param auth_data [Hash]
          # @return [String]
          def principal_id(auth_data)
            auth_data.with_indifferent_access[:identity_id]
          end

          # @return [String] new resource id
          def new_resource_id
            "#{self::RESOURCE[:name]}:#{NEW_RESOURCE_ID}"
          end

          # @param command [Yes::Core::Command] command to authorize
          # @return [Array<String>] actions for Cerbos check_resource
          def actions(command)
            [command.class.to_s.gsub(/::Commands?/, '').split('::').last.underscore]
          end

          # @param command [Yes::Core::Command] command to authorize
          # @return [String] scope for Cerbos check_resource
          def scope(command)
            command.class.to_s.split('::').first.underscore
          end
        end
      end
    end
  end
end
