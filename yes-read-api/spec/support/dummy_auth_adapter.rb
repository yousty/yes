# frozen_string_literal: true

# JWT-based auth adapter for testing read API request specs.
# Verifies ED25519-signed JWT tokens using the configured public key.
#
# @example Configuring
#   Yes::Core.configuration.auth_adapter = DummyAuthAdapter.new
class DummyAuthAdapter
  AuthError = Class.new(Yes::Core::AuthenticationError)

  # Authenticates the request by validating the JWT bearer token.
  # Returns auth data on success (required by read API controller).
  #
  # @param request [ActionDispatch::Request] the incoming request
  # @raise [AuthError] if no valid token is present
  # @return [Hash] auth data with identity_id and host
  def authenticate(request)
    token = extract_token(request)
    raise AuthError, 'Authentication token missing' unless token

    decoded = decode_token(token)
    raise AuthError, 'Invalid authentication token' unless decoded

    decoded.slice(:identity_id, :host).compact
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

  # Returns error classes that the controller should rescue.
  #
  # @return [Array<Class>] error classes
  def error_classes
    [AuthError, Yes::Core::AuthenticationError]
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
