# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # Cerbos-based command authorizer base class.
      #
      # Subclasses must define a RESOURCE constant:
      #   RESOURCE = { name: 'apprenticeship', read_model: Apprenticeship, draft_read_model: ApprenticeshipDraft }
      #
      # @abstract
      class CommandCerbosAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        NEW_RESOURCE_ID = 'new'

        class << self
          include OpenTelemetry::Trackable
          include CerbosClientProvider

          # @param command [Yes::Core::Command] command to authorize
          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if command is authorized
          # @raise [CommandNotAuthorized] if command is not authorized
          def call(command, auth_data)
            singleton_class.current_span&.add_attributes({ 'command' => command.to_json })

            check_principal_id_present(auth_data)
            singleton_class.current_span&.add_event('Principal Id Checked')

            resource = load_resource(command)
            singleton_class.current_span&.add_event('Resource Loaded')

            decision = authorize(command, resource, auth_data)
            singleton_class.current_span&.add_event('Cerbos Decision', attributes: { 'decision' => decision.to_json })

            return true if decision.allow_all?

            raise_command_unauthorized_error!(decision)
          end
          otl_trackable :call, OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Cerbos Authorize Command')

          private

          # @param decision [Cerbos::Output::CheckResources::Result]
          # @raise [CommandNotAuthorized]
          def raise_command_unauthorized_error!(decision)
            msg = 'You are not allowed to execute this command'
            singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error(msg)

            raise self::CommandNotAuthorized.new(msg, extra: { decision: decision.outputs.map(&:value) })
          end

          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if identity_id is present in auth_data
          # @raise [CommandNotAuthorized] if identity_id is not present in auth_data
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

            read_model(command).find_by(id: command.send("#{self::RESOURCE[:name]}_id"))
          end

          # Returns the appropriate read model class for the command.
          # Uses the draft read model when the command is an edit template command
          # and a draft_read_model is configured in RESOURCE.
          #
          # @param command [Yes::Core::Command] command to authorize
          # @return [Class] the read model class
          def read_model(command)
            return self::RESOURCE[:draft_read_model] if command.metadata&.dig(:edit_template_command) && self::RESOURCE[:draft_read_model]

            self::RESOURCE[:read_model]
          end

          # @param command [Yes::Core::Command]
          # @param resource [ActiveRecord::Base]
          # @param auth_data [Hash]
          # @return [Cerbos::Output::CheckResources::Result]
          def authorize(...)
            singleton_class.current_span&.add_event('Authorization Started')
            payload = cerbos_payload(...)
            singleton_class.current_span&.add_event('Cerbos Payload Built')

            singleton_class.with_otl_span('Authorize request to Cerbos') do
              cerbos_client.check_resource(**payload)
            end
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
            attribs = resource_attributes(resource, command)
            {
              kind: resource_kind(resource, attribs),
              scope: scope(command),
              id: resource_id(resource),
              attributes: attribs
            }
          end

          # @param resource [ActiveRecord::Base] resource to authorize
          # @param attribs [Hash] resource attributes
          # @return [String] resource kind for Cerbos check_resource
          def resource_kind(resource, attribs)
            (attribs.values.any? { !_1.nil? } || attribs.empty?) && resource&.id ? self::RESOURCE[:name] : new_resource_id
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
