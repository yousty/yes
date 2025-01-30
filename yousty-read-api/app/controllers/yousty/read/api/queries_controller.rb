# frozen_string_literal: true

module Yousty
  module Read
    module Api
      class QueriesController < ApplicationController
        include JwtTokenAuthClientRails::JwtTokenAuthController

        before_action :authenticate_with_token

        rescue_from(*TOKEN_AUTH_ERRORS, with: :jwt_token_error_response)

        rescue_from(
          Yousty::Eventsourcing::ReadModelsAuthorizer::NotAuthorized,
          Yousty::Eventsourcing::ReadRequestAuthorizer::NotAuthorized,
          with: :read_models_unauthorized_response
        )

        def call
          render json: response_json.to_json
        end

        private

        def response_json
          request_authorizer.call(params, auth_data)
          # TODO, use strong params filter_params
          records = filter(read_model_name).new(params).call
          paginated_records = paginate(records, params[:page] || {})

          Yousty::Eventsourcing::ReadModelsAuthorizer.call(read_model_name, paginated_records, auth_data)

          serialize(paginated_records)
        end

        def request_authorizer
          authorizer_class = "ReadModels::#{read_model_name.classify}::RequestAuthorizer"
          Kernel.const_get(authorizer_class)
        rescue NameError
          raise Yousty::Eventsourcing::ReadRequestAuthorizer::NotAuthorized, 'Not allowed'
        end

        def read_model_name
          params[:model].underscore
        end

        def filter(read_model_name)
          filter_class = "ReadModels::#{read_model_name.classify}::Filter"
          Kernel.const_get(filter_class)
        rescue NameError
          Yousty::Eventsourcing::ReadModelFilter
        end

        def serialize(records)
          # TODO, use strong params not to pass all params
          options = { params:, include: params[:include]&.split(',')&.map(&:to_sym) }.compact

          serializer.new(records, options)
        end

        def serializer
          serializer_class = "ReadModels::#{read_model_name.classify}::Serializers::#{read_model_name.classify}"
          Kernel.const_get(serializer_class)
        end

        def params
          request.parameters.deep_symbolize_keys
        end

        def jwt_token_error_response(error)
          render(
            json: { title: 'Auth Token Invalid', details: error.message }.to_json,
            status: :unauthorized
          )
        end

        def read_models_unauthorized_response(error)
          render(
            json: { title: 'Unauthorized', details: error.extra || error.message }.to_json,
            status: :unauthorized
          )
        end
      end
    end
  end
end
