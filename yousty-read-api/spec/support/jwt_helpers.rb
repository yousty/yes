# frozen_string_literal: true

module JwtHelpers
  def jwt_sign_in(expires_at: 1.hour.from_now, host: nil, identity_id: nil)
    generate_spec_token(expires_at, host:, identity_id:)
  end

  def generate_spec_token(expires_at, data)
    private_key = RbNaCl::Signatures::Ed25519::SigningKey.new(
      ENV.fetch('JWT_TOKEN_AUTH_PRIVATE_KEY')
    )
    JWT.encode(
      data.merge(exp: expires_at.to_i), private_key, 'ED25519'
    )
  end
end
