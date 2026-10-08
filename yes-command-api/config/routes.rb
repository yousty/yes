# frozen_string_literal: true

module Yes
  module Command
    module Api
      class OtlTrackableRequest
        def call(env)
          tracer = Yes::Core.configuration.otl_tracer
          controller = Yes::Command::Api::V1::CommandsController

          return controller.action(:execute).call(env) unless tracer

          tracer.in_span("Request #{controller}", kind: :client) do |request_span|
            request_span.add_attributes(otl_auth_data(env))

            Yes::Command::Api::V1::CommandsController.action(:execute).call(env).tap do |status, _headers, rack_response|
              tracer.in_span("Response #{controller}", kind: :client) do |response_span|
                response_span.status = OpenTelemetry::Trace::Status.error if status >= 300
                response_span.add_attributes(
                  {
                    'response.status': status,
                    'response.body': rack_response.body
                  }.stringify_keys
                )
              end
            end
          end
        end

        private

        def otl_auth_data(env)
          request = Rack::Request.new(env)

          request.body.rewind
          params = request.body.read
          request.body.rewind

          auth_token = env['HTTP_AUTHORIZATION'] || ''
          auth_data = unverified_auth_data(auth_token)
          {
            auth_token:,
            auth_data: auth_data.to_json,
            params:
          }.stringify_keys
        end

        # Decodes the bearer token without verifying it, only to enrich the span. A missing or
        # undecodable token yields an empty result: span enrichment must never decide the outcome
        # of the request, the controller answers with 401 for such tokens.
        #
        # @param auth_token [String] the raw Authorization header value (may be empty)
        # @return [Array<Hash>, Hash] the decoded JWT payload and header, or an empty hash
        def unverified_auth_data(auth_token)
          return {} if auth_token.blank?

          JWT.decode(auth_token.gsub('Bearer ', ''), nil, false)
        rescue JWT::DecodeError
          {}
        end
      end
    end
  end
end

Yes::Command::Api::Engine.routes.draw do
  post '/', to: Yes::Command::Api::OtlTrackableRequest.new
end
