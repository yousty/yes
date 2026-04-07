# frozen_string_literal: true

module Yes
  module Core
    module ProcessManagers
      # Handles communication with external command API services.
      #
      # @example
      #   client = Yes::Core::ProcessManagers::ServiceClient.new('my_service')
      #   client.call(access_token: token, commands_data: [...], channel: '/pm/channel')
      class ServiceClient
        # @return [String] the URL of the service to communicate with
        attr_reader :service_url
        private :service_url

        # Initializes a new ServiceClient.
        #
        # @param service [String] the name of the service to connect to
        def initialize(service)
          @service_url = ENV.fetch(
            "#{service.upcase}_SERVICE_URL",
            "http://#{service.underscore.tr('_', '-')}-cluster-ip-service:3000"
          )
        end

        # Sends commands to the service.
        #
        # @param access_token [String] JWT token for authentication
        # @param commands_data [Array<Hash>] array of command data to be sent
        # @param channel [String] the channel to send command notifications to
        # @return [Faraday::Response] the response from the service
        # @raise [ArgumentError] if access_token or channel is nil
        def call(access_token: nil, commands_data: [], channel: nil)
          raise ArgumentError, 'channel and access_token is required' if access_token.nil? || channel.nil?

          connection(access_token).post do |req|
            req.url '/v1/commands'
            req.body = { channel:, commands: commands_data }
          end
        end

        private

        # Creates a Faraday connection to the service.
        #
        # @param access_token [String] JWT token for authentication
        # @return [Faraday::Connection] the configured Faraday connection
        def connection(access_token)
          Faraday.new(service_url) do |f|
            f.request :json
            f.request :authorization, 'Bearer', access_token
          end
        end
      end
    end
  end
end
