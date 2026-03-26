# frozen_string_literal: true

require 'ostruct'

# Simple auth adapter for testing. Does not verify JWT tokens —
# just extracts the bearer token and returns it as identity_id.
# For JWT-based testing, see yes-command-api/spec/support/dummy_auth_adapter.rb
class DummyAuthAdapter
  AuthError = Class.new(Yes::Core::AuthenticationError)

  def authenticate(request)
    token = extract_token(request)
    raise AuthError, 'Authentication token missing' unless token

    { identity_id: token, host: request.host }
  end

  def auth_data(request)
    token = extract_token(request)
    return {} unless token

    { identity_id: token, host: request.host }
  end

  def verify_token(token)
    ::OpenStruct.new(token: [{ 'identity_id' => token }])
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
