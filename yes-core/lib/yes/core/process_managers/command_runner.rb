# frozen_string_literal: true

module Yes
  module Core
    module ProcessManagers
      # Publishes commands to a command API client with automatic access token retrieval.
      #
      # @abstract Subclass and override {#call} to implement command publishing logic.
      #
      # @example
      #   class MyCommandRunner < Yes::Core::ProcessManagers::CommandRunner
      #     def call(event)
      #       publish(
      #         client_id: ENV['CLIENT_ID'],
      #         client_secret: ENV['CLIENT_SECRET'],
      #         commands_data: [{ context: 'Foo', aggregate: 'Bar', command: 'create', params: {} }]
      #       )
      #     end
      #   end
      class CommandRunner < Base
        # @return [AccessTokenClient] client for retrieving access tokens
        attr_reader :access_token_client

        # @return [ServiceClient] client for sending commands to the API
        attr_reader :command_api_client

        # @return [Logger] logger instance for error logging
        attr_reader :logger

        private :access_token_client, :command_api_client, :logger

        # Initializes a new CommandRunner instance.
        #
        # @param command_api_client [ServiceClient, nil] the API client to use for sending commands
        def initialize(command_api_client: nil)
          super()

          @command_api_client = command_api_client
          @access_token_client = AccessTokenClient.new
          @logger = Rails.logger
        end

        private

        # Publishes commands to the API.
        #
        # @param client_id [String] the client ID for authentication
        # @param client_secret [String] the client secret for authentication
        # @param commands_data [Array<Hash>] the commands to be published
        # @param custom_command_api_client [ServiceClient, nil] optional custom API client
        # @return [Faraday::Response] the API response
        # @raise [ArgumentError] if no API client is available
        # @raise [Yes::Core::ProcessManagers::Base::Error] if the API request fails
        def publish(client_id:, client_secret:, commands_data:, custom_command_api_client: nil)
          access_token = access_token_client.call(client_id:, client_secret:)
          api_client = custom_command_api_client || command_api_client

          if api_client.nil?
            raise ArgumentError, 'No API client available. Ensure custom_command_api_client is provided ' \
                                 'or command_api_client is initialized.'
          end

          response = api_client.call(access_token:, commands_data:, channel:)
          process_manager_error!(response) unless response.success?

          response
        end

        # Generates the channel name based on the class name.
        #
        # @return [String] the channel name
        # @example
        #   "/process_managers/do_something_manager"
        def channel
          "/#{self.class.name.split('::').first(2).flatten.join('/').underscore}"
        end

        # Processes and logs errors from the API response.
        #
        # @param response [Faraday::Response] the API response
        # @param error_msg [String, nil] additional error message
        # @raise [Yes::Core::ProcessManagers::Base::Error] with detailed error information
        def process_manager_error!(response, error_msg: nil)
          msg = 'Process Manager: failed to send commands'

          extra = {
            error_msg:,
            request: {
              url: response.env.url.to_s,
              body: JSON.parse(response.env.request_body),
              token: response.env.request_headers['Authorization']
            },
            response: {
              body: begin
                JSON.parse(response.body)
              rescue StandardError
                response.body
              end,
              status: response.status
            }
          }

          logger.error("#{msg} extra: #{extra}")
          raise Yes::Core::ProcessManagers::Base::Error.new(msg, extra:)
        end
      end
    end
  end
end
