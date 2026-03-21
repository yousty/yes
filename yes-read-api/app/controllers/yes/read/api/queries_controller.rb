# frozen_string_literal: true

require 'yes/read/api/advanced_filter_validator'

module Yes
  module Read
    module Api
      class QueriesController < ApplicationController
        before_action :authenticate_with_token
        before_action :validate_advanced_payload, only: :advanced
        before_action :process_own_filter, only: :call

        rescue_from(Yes::Core::AuthenticationError, with: :auth_error_response)

        rescue_from(
          Yes::Core::Authorization::ReadModelsAuthorizer::NotAuthorized,
          Yes::Core::Authorization::ReadRequestAuthorizer::NotAuthorized,
          with: :read_models_unauthorized_response
        )

        def call
          if params[:filter_id].present?
            persisted_filter = filter(read_model_name).persisted_filter_scope.find_by(id: params[:filter_id])
          end

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
          filter_options = persisted_filter&.body&.deep_symbolize_keys&.merge(model: params[:model]) || params

          request_authorizer.call(filter_options, auth_data)

          filter_options[:filters] ||= {}
          records = filter(read_model_name).new(filter_options, type: filter_type).call
          paginated_records = paginate(records, filter_options[:page] || {})

          Yes::Core::Authorization::ReadModelsAuthorizer.call(read_model_name, paginated_records, auth_data)

          serialize(paginated_records, filter_options)
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

        def authenticate_with_token
          adapter = Yes::Core.configuration.auth_adapter
          raise Yes::Core::AuthenticationError, 'No auth adapter configured' if adapter.nil?

          @auth_data = adapter.authenticate(request)
        end

        def auth_data
          @auth_data
        end

        def auth_error_response(error)
          render(
            json: { title: 'Auth Token Invalid', details: error.message }.to_json,
            status: :unauthorized
          )
        end

        def read_models_unauthorized_response(error)
          render(
            json: { title: 'Unauthorized', details: error.message }.to_json,
            status: :unauthorized
          )
        end

        def validate_advanced_payload
          return if params[:filter_definition].blank?

          validation_result = Yes::Read::Api::AdvancedFilterValidator.call(params)
          return if validation_result.success?

          render(
            json: { title: 'Invalid Payload', details: validation_result.errors.to_h }.to_json,
            status: :unprocessable_entity
          )
        end
      end
    end
  end
end
