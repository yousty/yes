# frozen_string_literal: true

# Simple auth adapter for development/manual testing.
# Trusts the bearer token as a JSON-encoded auth data hash.
#
# Usage:
#   # Generate a token:
#   require 'base64'
#   token = Base64.strict_encode64({ identity_id: 'some-uuid', user_id: 'some-uuid' }.to_json)
#
#   # Use in request:
#   curl -H "Authorization: Bearer <token>" ...
class DevAuthAdapter
  AuthError = Class.new(Yes::Core::AuthenticationError)

  def authenticate(request)
    token = extract_token(request)
    raise AuthError, 'Authentication token missing' unless token

    auth_data(request)
  end

  def auth_data(request)
    token = extract_token(request)
    return {} unless token

    JSON.parse(Base64.strict_decode64(token)).symbolize_keys
  rescue ArgumentError, JSON::ParserError
    {}
  end

  def verify_token(token)
    payload = JSON.parse(Base64.strict_decode64(token))
    OpenStruct.new(token: [payload])
  rescue ArgumentError, JSON::ParserError
    OpenStruct.new(token: [{}])
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
end
