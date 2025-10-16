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
class OtlTrackableRequest
  attr_accessor :action, :controller

  def initialize(action:, controller:)
    @action = action
    @controller = controller
  end

  def call(env)
    tracer = Yousty::Eventsourcing.config.otl_tracer
    request = ActionDispatch::Request.new(env)

    controller ||= request.controller_class
    action ||= request.params[:action] || :index

    return controller.action(action).call(env) unless tracer

    otl_request_data = request.get? || request.delete? ? get_otl_auth_data(request, env) : otl_auth_data(request, env)

    if tracer.current_span
      tracer.current_span.add_attributes(otl_request_data)

      controller.action(action).call(env)
    else
      tracer.in_span("Request #{controller}", kind: :client) do |request_span|
        request_span.add_attributes(otl_request_data)

        controller.action(action).call(env)
      end
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

Yes::Read::Api::Engine.routes.draw do
  constraints(Yes::Read::Api::ModelConstraints) do
    get '/:model', to: OtlTrackableRequest.new(action: :call, controller: Yes::Read::Api::QueriesController)
    post '/:model', to: OtlTrackableRequest.new(action: :advanced, controller: Yes::Read::Api::QueriesController)
  end
end
