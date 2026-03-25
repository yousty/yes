# frozen_string_literal: true

module Yes
  module Core
    module ProcessManagers
      # Client for obtaining access tokens using client credentials.
      #
      # @example
      #   client = Yes::Core::ProcessManagers::AccessTokenClient.new
      #   access_token = client.call(client_id: 'id', client_secret: 'secret')
      class AccessTokenClient
        # Custom error class for AccessTokenClient failures.
        class Error < StandardError
          # @return [Hash] additional error context
          attr_accessor :extra

          # @param msg [String] the error message
          # @param extra [Hash] additional error information
          def initialize(msg, extra: {})
            @extra = extra
            super(msg)
          end
        end

        # Holds structured response data from the token request.
        Response = Data.define(:response, :request_body, :request_url, :body, :parsed_body, :status_code)

        # @return [String] the authentication service URL
        AUTH_URL = ENV.fetch('AUTH_URL', 'http://auth-cluster-ip-service:3000/v1')

        # @return [String] the OAuth2 grant type
        GRANT_TYPE = 'client_credentials'

        # @return [Faraday::Connection] the HTTP connection
        attr_reader :connection
        private :connection

        # Initializes the AccessTokenClient with a Faraday connection.
        def initialize
          @connection = Faraday.new(AUTH_URL) do |f|
            f.request :json
          end
        end

        # Requests an access token using client credentials.
        #
        # @param client_id [String] the client ID
        # @param client_secret [String] the client secret
        # @return [String] the access token
        # @raise [Error] if the access token cannot be obtained
        def call(client_id:, client_secret:)
          payload = { client_id:, client_secret:, grant_type: GRANT_TYPE }

          response = perform_request(payload)
          access_token_error!(response) unless response.response.success?

          return response.parsed_body['access_token'] if response.parsed_body&.dig('access_token')

          access_token_error!(response)
        end

        private

        # Performs the HTTP request to obtain the access token.
        #
        # @param payload [Hash] the request payload
        # @return [Response] the response object
        def perform_request(payload)
          response = connection.post do |req|
            req.url 'oauth/token'
            req.body = payload
          end
          Response.new(
            response:,
            request_url: response.env.url.to_s,
            request_body: payload,
            body: response.body,
            parsed_body: parse_response(response.body),
            status_code: response.status
          )
        end

        # Parses the JSON response body.
        #
        # @param body [String] the response body
        # @return [Hash, nil] the parsed JSON or nil if parsing fails
        def parse_response(body)
          JSON.parse(body)
        rescue JSON::ParserError
          nil
        end

        # Raises an error with details about the failed access token request.
        #
        # @param response [Response] the response object
        # @raise [Error] with details about the failed request
        def access_token_error!(response)
          msg = 'Access Token Client: failed to get access token'

          extra = {
            request: {
              url: response.request_url,
              body: response.request_body.merge(client_secret: '[FILTERED]')
            },
            response: {
              body: response.parsed_body || response.body,
              status: response.status_code
            }
          }

          Rails.logger.error("#{msg} extra: #{extra}")
          raise Error.new(msg, extra:)
        end
      end
    end
  end
end
