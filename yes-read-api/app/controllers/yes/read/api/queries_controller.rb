# frozen_string_literal: true

require 'yes/read/api/advanced_filter_validator'

module Yes
  module Read
    module Api
      class QueriesController < ApplicationController
        before_action :authenticate_with_token
        before_action :reject_ignored_filter_param
        before_action :validate_advanced_payload, only: :advanced
        before_action :process_own_filter, only: :call

        RETRY_AFTER_SECONDS = 1
        FILTER_DEFINITION_REQUIRED = 'filter_definition is required for an advanced query'
        FILTERS_IGNORED_BY_ADVANCED = 'filters is not applied by an advanced query, use filter_definition'
        STORED_FILTER_WITHOUT_DEFINITION = 'the stored filter has no filter_definition'
        FILTER_DEFINITION_IGNORED_BY_BASIC = 'filter_definition is not applied by a basic query, use filters'

        # Covers AuthenticationError raised outside #authenticate_with_token, e.g. by consumer
        # request authorizers, filters or serializers.
        rescue_from(Yes::Core::AuthenticationError, with: :auth_error_response)

        rescue_from(
          Yes::Core::Authorization::ReadModelsAuthorizer::NotAuthorized,
          Yes::Core::Authorization::ReadRequestAuthorizer::NotAuthorized,
          with: :read_models_unauthorized_response
        )

        rescue_from(
          Cerbos::Error::Unavailable,
          Cerbos::Error::DeadlineExceeded,
          with: :authorization_service_unavailable_response
        )

        def call
          persisted_filter = filter(read_model_name).persisted_filter_scope.find_by(id: params[:filter_id]) if params[:filter_id].present?

          return bad_request_response(STORED_FILTER_WITHOUT_DEFINITION) if without_definition?(persisted_filter)

          render json: response_json(persisted_filter:, filter_type: persisted_filter ? :advanced : :basic).to_json
        end

        def advanced
          render json: response_json(filter_type: :advanced).to_json
        end

        private

        def process_own_filter
          return if params.dig(:filters, :own).blank?
          return unless defined?(::IdentityUser)

          identity_user = ::IdentityUser.find_by(id: auth_data[:identity_id])
          return if identity_user.blank?
          return unless identity_user.respond_to?("own_#{read_model_name.singularize}_ids")

          owned_ids = identity_user.send("own_#{read_model_name.singularize}_ids")
          params[:filters][:ids] = owned_ids.presence&.join(',') || 'none'
        end

        def response_json(filter_type: :basic, persisted_filter: nil)
          filter_options = applied_filter_options(persisted_filter:)

          request_authorizer.call(filter_options, auth_data)

          filter_options[:filters] ||= {}
          records = filter(read_model_name).new(filter_options, type: filter_type).call
          paginated_records = paginate(records, filter_options[:page] || {})

          Yes::Core::Authorization::ReadModelsAuthorizer.call(read_model_name, paginated_records, auth_data)

          serialize(paginated_records, filter_options)
        end

        # The options the query is built from. They are what the request authorizer is handed too.
        # A stored filter body replaces the request params and runs as an advanced query, which
        # applies `filter_definition` only, so a `filters` key in the body is dropped.
        #
        # @param persisted_filter [#body, nil] stored filter whose body replaces the request params
        # @return [Hash] the stored body (without `filters`) or the request params
        def applied_filter_options(persisted_filter:)
          return params unless persisted_filter

          stored_filter_options(persisted_filter).except(:filters)
        end

        # An advanced query returns the unbounded base scope without a `filter_definition`.
        #
        # @param persisted_filter [#body, nil] stored filter
        # @return [Boolean] whether a stored filter was found whose body has no `filter_definition`;
        #   a body that is not a Hash (the jsonb column also holds nil, arrays, strings) has none
        def without_definition?(persisted_filter)
          return false if persisted_filter.blank?
          return true unless persisted_filter.body.is_a?(Hash)

          stored_filter_options(persisted_filter)[:filter_definition].blank?
        end

        # @param persisted_filter [#body] stored filter with a Hash body
        # @return [Hash] its body with symbol keys and the requested model
        def stored_filter_options(persisted_filter)
          persisted_filter.body.deep_symbolize_keys.merge(model: params[:model])
        end

        def request_authorizer
          authorizer_class = "ReadModels::#{read_model_name.classify}::RequestAuthorizer"
          Kernel.const_get(authorizer_class)
        rescue NameError
          raise Yes::Core::Authorization::ReadRequestAuthorizer::NotAuthorized, 'Not allowed'
        end

        def read_model_name
          params[:model].underscore
        end

        def filter(read_model_name)
          filter_class = "ReadModels::#{read_model_name.classify}::Filter"
          Kernel.const_get(filter_class)
        rescue NameError
          Yes::Core::ReadModel::Filter
        end

        def serialize(records, filter_options)
          options = {
            params: filter_options,
            include: filter_options[:include]&.split(',')&.map(&:to_sym),
            auth_data:
          }.compact

          serializer.new(records, options)
        end

        def serializer
          serializer_class = "ReadModels::#{read_model_name.classify}::Serializers::#{read_model_name.classify}"
          Kernel.const_get(serializer_class)
        end

        def params
          @params ||= request.parameters.deep_symbolize_keys
        end

        # Authenticates the request using the configured auth adapter and stores the returned auth data.
        # Rescues at call time (not via rescue_from) because the adapter, and with it its error
        # classes, is configured in an initializer that may run after this controller loads.
        #
        # @return [void]
        def authenticate_with_token
          adapter = Yes::Core.configuration.auth_adapter
          raise Yes::Core::AuthenticationError, 'No auth adapter configured' if adapter.nil?

          @auth_data = adapter.authenticate(request)
        rescue *Yes::Core.configuration.auth_error_classes => e
          auth_error_response(e)
        end

        attr_reader :auth_data

        # Renders a 401 for an authentication failure.
        #
        # @param error [StandardError] the error raised by the auth adapter
        # @return [void]
        def auth_error_response(error)
          render(
            json: { title: 'Auth Token Invalid', detail: error.message }.to_json,
            status: :unauthorized
          )
        end

        def read_models_unauthorized_response(error)
          render(
            json: { title: 'Unauthorized', detail: error.message }.to_json,
            status: :unauthorized
          )
        end

        # Renders a 503 when the authorization service cannot be reached; the client can retry.
        def authorization_service_unavailable_response(error)
          Rails.error.report(error, handled: true, severity: :error)

          response.set_header('Retry-After', RETRY_AFTER_SECONDS.to_s)
          render(
            json: { title: 'Service Unavailable', detail: 'Authorization service unavailable' }.to_json,
            status: :service_unavailable
          )
        end

        # Rejects a request that carries the filter parameter its query does not apply, or lacks the one
        # it needs. Request authorizers pick what to check by which parameter is present, so a parameter
        # the query silently ignores could be authorized without bounding the result. It runs as a
        # before_action, so consumer actions of subclasses are covered too.
        #
        # @return [void]
        def reject_ignored_filter_param
          if request.post?
            return bad_request_response(FILTER_DEFINITION_REQUIRED) if params[:filter_definition].blank?

            bad_request_response(FILTERS_IGNORED_BY_ADVANCED) if params.key?(:filters)
          elsif params.key?(:filter_definition)
            bad_request_response(FILTER_DEFINITION_IGNORED_BY_BASIC)
          end
        end

        # Renders a 400 with the reason the request is malformed.
        #
        # @param detail [String] why the request is rejected and what to send instead
        # @return [void]
        def bad_request_response(detail)
          render(json: { title: 'Bad Request', detail: }.to_json, status: :bad_request)
        end

        def validate_advanced_payload
          validation_result = Yes::Read::Api::AdvancedFilterValidator.call(params)
          return if validation_result.success?

          render(
            json: { title: 'Invalid Payload', detail: validation_result.errors.to_h }.to_json,
            status: :unprocessable_content
          )
        end
      end
    end
  end
end
