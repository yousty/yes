# frozen_string_literal: true

# Simple auth adapter for testing command API request specs.
# Extracts identity_id from a Base64-encoded JSON bearer token.
#
# @example Generating a token
#   token = Base64.strict_encode64({ identity_id: SecureRandom.uuid }.to_json)
#
# @example Configuring
#   Yes::Core.configuration.auth_adapter = DummyAuthAdapter.new
class DummyAuthAdapter
  # Authenticates the request by validating the bearer token.
  #
  # @param request [ActionDispatch::Request] the incoming request
  # @raise [Yes::Core::AuthenticationError] if no valid token is present
  # @return [void]
  def authenticate(request)
    token = extract_token(request)
    raise Yes::Core::AuthenticationError, 'Missing or invalid auth token' unless token

    decoded = decode_token(token)
    raise Yes::Core::AuthenticationError, 'Invalid token payload' unless decoded&.key?('identity_id')
  end

  # Returns auth data extracted from the bearer token.
  #
  # @param request [ActionDispatch::Request] the incoming request
  # @return [Hash] auth data with identity_id
  def auth_data(request)
    token = extract_token(request)
    return {} unless token

    decoded = decode_token(token)
    { identity_id: decoded['identity_id'] }.compact
  end

  # Returns error classes that the controller should rescue.
  #
  # @return [Array<Class>] error classes
  def error_classes
    [Yes::Core::AuthenticationError]
  end

  private

  # @param request [ActionDispatch::Request] the incoming request
  # @return [String, nil] the raw bearer token
  def extract_token(request)
    header = request.headers['Authorization']
    return nil unless header&.start_with?('Bearer ')

    header.delete_prefix('Bearer ')
  end

  # @param token [String] Base64-encoded JSON token
  # @return [Hash, nil] decoded token payload
  def decode_token(token)
    JSON.parse(Base64.strict_decode64(token))
  rescue ArgumentError, JSON::ParserError
    nil
  end
end
