# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # @abstract Read request Cerbos authorizer base class. Subclass and override call method to implement
      # a custom authorizer.
      class ReadRequestCerbosAuthorizer < Yes::Core::Authorization::ReadRequestAuthorizer
        class << self
          include OpenTelemetry::Trackable

          # Implement this method to authorize a read request.
          # Needs to return true if read request is authorized, otherwise raise NotAuthorized.
          # @param params [Hash] request params to authorize
          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if read request is authorized raises NotAuthorized otherwise
          # @raise [NotAuthorized] if read request is not authorized
          def call(params, auth_data)
            singleton_class.current_span&.add_attributes(
              { params: params.to_json, auth_data: auth_data.to_json }.stringify_keys
            )
            auth_data = auth_data.with_indifferent_access

            check_authorization_data(params) unless super_admin?(auth_data)

            decision = authorize(params, auth_data)
            singleton_class.current_span&.add_event('Cerbos Decision', attributes: { 'decision' => decision.to_json })
            return true if decision.allow_all?

            raise_unauthorized_error!(params, decision)
          end
          otl_trackable :call, OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Cerbos Authorize Read Request')

          private

          # @param params [Hash]
          # @param decision [Cerbos::Decision] decision from Cerbos
          # raise [NotAuthorized]
          def raise_unauthorized_error!(params, decision)
            msg = "You don't have access to these #{params[:model]}"
            singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error(msg)

            raise self::NotAuthorized.new(msg, extra: { decision: decision.outputs.map(&:value) })
          end

          # @param params [Hash] request params to authorize
          # @return [Boolean] true if user is a super admin
          # @raise [NotAuthorized]
          def check_authorization_data(_params)
            raise NotImplementedError, 'You need to implement check_authorization_data'
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

          # @param params [Hash] request params to authorize
          # @param auth_data [Hash] authorization data
          # @return [Hash] payload for Cerbos check_resource
          def cerbos_payload(params, auth_data)
            {
              principal: principal_data(auth_data),
              resource: resource_data(params),
              actions: actions(params),
              include_metadata: Yes::Core.configuration.cerbos_read_authorizer_include_metadata
            }.deep_symbolize_keys.tap { singleton_class.current_span&.set_attribute('cerbos_payload', _1.to_json) }
          end

          # @param params [Hash] request params to authorize
          # @return [Hash] resource data for Cerbos check_resource
          def resource_data(params)
            {
              scope:,
              kind: params[:model],
              id: resource_id(params),
              attributes: resource_attributes(params)
            }
          end

          # @param params [Hash]
          # @return [Hash]
          def resource_attributes(_params)
            {}
          end

          # @param auth_data [Hash] authorization data
          # @return [Hash] principal data for Cerbos check_resource
          def principal_data(auth_data)
            Yes::Core.configuration.cerbos_principal_data_builder.call(auth_data)
          end

          # @return [String] scope for Cerbos check_resource
          def scope
            Rails.application.class.module_parent_name.underscore
          end

          # @param params [Hash] request params to authorize
          def actions(_params)
            Yes::Core.configuration.cerbos_read_authorizer_actions
          end

          # @param params [Hash] request params to authorize
          # @return [String] resource id for Cerbos check_resource
          def resource_id(params)
            "#{Yes::Core.configuration.cerbos_read_authorizer_resource_id_prefix}#{params[:model]}"
          end
        end
      end
    end
  end
end
