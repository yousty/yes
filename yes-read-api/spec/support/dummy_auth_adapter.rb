# frozen_string_literal: true

require 'ostruct'

# JWT-based auth adapter for testing read API request specs.
class DummyAuthAdapter
  AuthError = Class.new(Yes::Core::AuthenticationError)

  def authenticate(request)
    token = extract_token(request)
    raise AuthError, 'Authentication token missing' unless token

    decoded = decode_token(token)
    raise AuthError, 'Invalid authentication token' unless decoded

    auth_data(request)
  end

  def auth_data(request)
    token = extract_token(request)
    return {} unless token

    decoded = decode_token(token)
    return {} unless decoded

    decoded.slice(:identity_id, :host).compact
  end

  def verify_token(token)
    decoded = decode_token(token)
    ::OpenStruct.new(token: [decoded&.stringify_keys || {}])
  end

  def error_classes
    [AuthError]
  end

  private

  def extract_token(request)
    header = request.headers['Authorization']
    return nil unless header&.start_with?('Bearer ')

    header.delete_prefix('Bearer ')
  end

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
