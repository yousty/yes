# frozen_string_literal: true

module Yes
  module Command
    module Api
      module V1
        # Controller for executing command batches via the command bus.
        #
        # Auth is delegated to the configured auth adapter in Yes::Core.configuration.
        # If no auth adapter is configured, authentication will raise an error.
        class CommandsController < ActionController::API
          MAX_INLINE_COMMANDS_PER_REQ = 10

          include Yes::Core::OpenTelemetry::Trackable

          before_action :authenticate_with_token
          before_action :set_channel

          rescue_from(StandardError, with: :handle_unexpected_error)

          rescue_from(
            Yes::Command::Api::Commands::ParamsValidator::CommandParamsInvalid,
            with: :command_params_invalid_response
          )

          rescue_from(
            Yes::Command::Api::Commands::Deserializer::DeserializationFailed,
            with: :deserialization_failed_response
          )

          rescue_from(
            Yes::Command::Api::Commands::BatchAuthorizer::CommandsNotAuthorized,
            with: :commands_unauthorized_response
          )

          rescue_from(
            Yes::Command::Api::Commands::BatchValidator::CommandsInvalid,
            with: :commands_invalid_response
          )

          # Executes a batch of commands.
          def execute
            Yes::Command::Api::Commands::ParamsValidator.call(params[:commands])
            deserialize_commands = Yes::Command::Api::Commands::Deserializer.call(params[:commands])
            expanded_commands = expand_commands(deserialize_commands)
            return too_many_inline_commands if perform_inline? && expanded_commands.size > MAX_INLINE_COMMANDS_PER_REQ

            Yes::Command::Api::Commands::BatchAuthorizer.call(expanded_commands, auth_data)
            Yes::Command::Api::Commands::BatchValidator.call(expanded_commands)
            cmd_bus_response = command_bus.call(
              add_metadata(deserialize_commands),
              notifier_options: { channel: @channel }
            )

            render json: success_response_data(cmd_bus_response), status: :ok
          end

          private

          # Authenticates the request using the configured auth adapter.
          # Stores the returned auth data for use in subsequent actions.
          #
          # @raise [RuntimeError] if no auth adapter is configured
          # @return [void]
          def authenticate_with_token
            adapter = Yes::Core.configuration.auth_adapter
            raise 'No auth adapter configured. Set Yes::Core.configuration.auth_adapter.' unless adapter

            @auth_data = adapter.authenticate(request)
          rescue *auth_error_classes => e
            auth_error_response(e)
          end

          # @return [Hash] the authentication data
          attr_reader :auth_data

          # Returns the error classes defined by the auth adapter.
          #
          # @return [Array<Class>] auth error classes
          def auth_error_classes
            Yes::Core.configuration.auth_adapter&.error_classes || []
          end

          def perform_inline?
            return false if params[:async] == 'true'
            return true if params[:async] == 'false'

            Yes::Core.configuration.process_commands_inline
          end

          def command_bus
            return Yes::Core::Commands::Bus.new unless perform_inline?

            Yes::Core::Commands::Bus.new(perform_inline: perform_inline?)
          end

          def too_many_inline_commands
            error = "Too many commands. You can process up to #{MAX_INLINE_COMMANDS_PER_REQ} commands inline."
            render json: { error: }, status: :unprocessable_entity
          end

          def expand_commands(deserialize_commands)
            deserialize_commands.map do |command|
              command.is_a?(Yes::Core::Commands::Group) ? command.commands : command
            end.flatten
          end

          def add_metadata(commands)
            commands.map do |command|
              command.class.new(
                command.to_h.merge(
                  metadata: (command.metadata || {}).merge(identity_id: auth_data[:identity_id], otl_contexts:)
                )
              )
            end
          end

          def success_response_data(cmd_bus_response)
            return { batch_id: cmd_bus_response.job_id } if cmd_bus_response.respond_to?(:job_id)

            cmd_bus_response
          end

          def params
            request.parameters.deep_symbolize_keys
          end

          def command_params_invalid_response(error)
            error_info = {
              title: 'Bad request',
              detail: { message: error.message }
            }
            error_info[:detail][:invalid] = error.extra if error.extra

            render json: error_info.to_json, status: :bad_request
          end

          def deserialization_failed_response(error)
            error_info = {
              title: 'Bad request',
              detail: error.extra
            }

            render json: error_info.to_json, status: :bad_request
          end

          # Handles auth token errors from the configured auth adapter.
          #
          # @param error [StandardError] the auth error
          # @return [void]
          def auth_error_response(error)
            render(
              json: { title: 'Auth Token Invalid', details: error.message }.to_json,
              status: :unauthorized
            )
          end

          def commands_unauthorized_response(error)
            render(
              json: { title: 'Unauthorized', details: error.extra }.to_json, status: :unauthorized
            )
          end

          def commands_invalid_response(error)
            error_info = {
              title: 'Unprocessable Entity',
              errors: error.extra
            }

            render json: error_info.to_json, status: 422
          end

          def set_channel
            @channel = params[:channel].presence || auth_data[:identity_id]

            self.class.current_span&.set_attribute('channel', @channel)
            return if @channel.present?

            render json: { title: '"channel" param is required' }, status: :bad_request
          end
          otl_trackable :set_channel,
                        Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(
                          span_name: 'Set Channel',
                          span_kind: :client
                        )

          def handle_unexpected_error(error)
            self.class.current_span&.status = OpenTelemetry::Trace::Status.error(error.message)
            self.class.current_span&.record_exception(error)

            raise error
          end
          otl_trackable :handle_unexpected_error,
                        Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Handle Unexpected Error')

          def command_request_started_at_ms
            return nil unless request.env['HTTP_X_REQUEST_START']

            (request.env['HTTP_X_REQUEST_START'].to_f * 1000).to_i
          end

          def otl_contexts
            {
              root: self.class.propagate_context(service_name: true),
              timestamps: { command_request_started_at_ms: }.compact
            }
          end
        end
      end
    end
  end
end
