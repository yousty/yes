# frozen_string_literal: true

require 'ostruct'

# JWT-based auth adapter for testing command API request specs.
# Verifies ED25519-signed JWT tokens using the configured public key.
#
# @example Configuring
#   Yes::Core.configuration.auth_adapter = DummyAuthAdapter.new
class DummyAuthAdapter
  AuthError = Class.new(StandardError)

  # Authenticates the request by validating the JWT bearer token.
  #
  # @param request [ActionDispatch::Request] the incoming request
  # @raise [AuthError] if no valid token is present
  # @return [void]
  def authenticate(request)
    token = extract_token(request)
    raise AuthError, 'Missing or invalid auth token' unless token

    decoded = decode_token(token)
    raise AuthError, 'Invalid token payload' unless decoded
  end

  # Returns auth data extracted from the JWT bearer token.
  #
  # @param request [ActionDispatch::Request] the incoming request
  # @return [Hash] auth data with identity_id and host
  def auth_data(request)
    token = extract_token(request)
    return {} unless token

    decoded = decode_token(token)
    return {} unless decoded

    decoded.slice(:identity_id, :host).compact
  end

  # Verifies a raw JWT token and returns a wrapper with the decoded payload.
  # Used by the MessageBus user_id_lookup initializer.
  #
  # @param token [String] raw JWT token
  # @return [OpenStruct] wrapper with .token returning [decoded_payload]
  def verify_token(token)
    decoded = decode_token(token)
    ::OpenStruct.new(token: [decoded&.stringify_keys || {}])
  end

  # Returns error classes that the controller should rescue.
  #
  # @return [Array<Class>] error classes
  def error_classes
    [AuthError]
  end

  private

  # @param request [ActionDispatch::Request] the incoming request
  # @return [String, nil] the raw bearer token
  def extract_token(request)
    header = request.headers['Authorization']
    return nil unless header&.start_with?('Bearer ')

    header.delete_prefix('Bearer ')
  end

  # @param token [String] JWT token
  # @return [Hash, nil] decoded token payload
  def decode_token(token)
    public_key = RbNaCl::Signatures::Ed25519::VerifyKey.new(
      [ENV.fetch('JWT_TOKEN_AUTH_PUBLIC_KEY')].pack('H*')
    )
    decoded = JWT.decode(token, public_key, true, algorithm: 'ED25519')
    decoded.first.deep_symbolize_keys
  rescue JWT::DecodeError, RbNaCl::CryptoError
    nil
  end
end
