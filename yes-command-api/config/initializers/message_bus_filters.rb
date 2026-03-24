# frozen_string_literal: true

return unless defined?(MessageBus)

# Filtering by params[:batch_id]. Applied to all channels
MessageBus.register_client_message_filter('') do |params, message|
  next true unless params.key?('batch_id')

  message.data['batch_id'].to_s == params['batch_id']
end

# Filtering by params[:type]. Applied to all channels
MessageBus.register_client_message_filter('') do |params, message|
  next true unless params.key?('type')

  message.data['type'] == params['type']
end

# Filtering by params[:command]. Applied to all channels
MessageBus.register_client_message_filter('') do |params, message|
  next true unless params.key?('command')

  message.data['command'] == params['command']
end

# Filtering by params[:since]. Applied to all channels
MessageBus.register_client_message_filter('') do |params, message|
  next true unless params.key?('since')
  next true unless message.data.key?('published_at')

  message.data['published_at'] >= params['since'].to_i
end

MessageBus.user_id_lookup do |env|
  request = ActionDispatch::Request.new(env)
  token, = ActionController::HttpAuthentication::Token.token_and_options(request)

  if token && Yes::Core.configuration.auth_adapter
    verified_token = Yes::Core.configuration.auth_adapter.verify_token(token)
    verified_token.token.first['identity_id']
  end
end
