# frozen_string_literal: true

# Instantiates an ActionDispatch::Request from the env.
# Extracts controller and action.
# Decides whether to:
# Just call the controller if no tracer is configured.
# Otherwise, start or enrich an OpenTelemetry span with authentication and request data.
# Returns the controller’s response (controller.action(action).call(env)).
# It’s being used as a route handler directly in Rails routes:
# get '/:model', to: OtlTrackableRequest.new
# post '/:model', to: OtlTrackableRequest.new
#

require 'jwt_token_auth_client_rails'

module Yes
  module Read
    module Api
      class OtlTrackableRequest
        attr_accessor :action_name, :controller_class

        def initialize(action_name:, controller_class: Yes::Read::Api::QueriesController)
          @action_name = action_name
          @controller_class = controller_class
        end

        def call(env)
          tracer = Yousty::Eventsourcing.config.try(:otl_tracer)
          request = ActionDispatch::Request.new(env)

          self.controller_class ||= request.controller_class
          self.action_name ||= request.params[:action] || :index

          return controller_class.action(action_name).call(env) if tracer.nil?

          otl_request_data = request.get? || request.delete? ? get_otl_auth_data(request, env) : otl_auth_data(request, env)

          tracer.in_span("Request #{controller_class.name}", kind: :client) do |request_span|
            request_span.add_attributes(otl_request_data)

            return controller_class.action(action_name).call(env)
          end
        end

        private

        def otl_auth_data(request, env)
          request.body.rewind
          params = request.body.read
          request.body.rewind # restore the cursor to the beginning able read again body

          auth_token = env['HTTP_AUTHORIZATION'] || ''
          auth_data =  auth_token.present? ? JWT.decode(auth_token.gsub('Bearer ', ''), nil, false) : {}
          {
            auth_token:,
            auth_data: auth_data.to_json,
            params:
          }.stringify_keys
        end

        def get_otl_auth_data(request, env)
          auth_token = env['HTTP_AUTHORIZATION'] || ''
          auth_data =  auth_token.present? ? JWT.decode(auth_token.gsub('Bearer ', ''), nil, false) : {}
          {
            auth_token:,
            auth_data: auth_data.to_json,
            params: request.params.to_json
          }.stringify_keys
        end
      end
    end
  end
end

Yes::Read::Api::Engine.routes.draw do
  constraints(Yes::Read::Api::ModelConstraints) do
    get '/:model', to: Yes::Read::Api::OtlTrackableRequest.new(action_name: :call)
    post '/:model', to: Yes::Read::Api::OtlTrackableRequest.new(action_name: :advanced)
  end
end
