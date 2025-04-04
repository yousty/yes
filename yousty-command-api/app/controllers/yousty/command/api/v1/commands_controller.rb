# frozen_string_literal: true

# rubocop:disable Rails/HttpStatus

module Yousty
  module Command
    module Api
      module V1
        class CommandsController < ActionController::API
          MAX_INLINE_COMMANDS_PER_REQ = 10

          include JwtTokenAuthClientRails::JwtTokenAuthController

          before_action :authenticate_with_token
          before_action :set_channel

          rescue_from(*TOKEN_AUTH_ERRORS, with: :jwt_token_error_response)

          rescue_from(
            Yousty::Eventsourcing::CommandParamsValidator::CommandParamsInvalid,
            with: :command_params_invalid_response
          )

          rescue_from(
            Yousty::Eventsourcing::CommandsDeserializer::DeserializationFailed,
            with: :deserialization_failed_response
          )

          rescue_from(
            Yousty::Eventsourcing::CommandsAuthorizer::CommandsNotAuthorized,
            with: :commands_unauthorized_response
          )

          rescue_from(
            Yousty::Eventsourcing::CommandsValidator::CommandsInvalid,
            with: :commands_invalid_response
          )

          # Executes a batch of commands.
          #
          # Documentation:  https://app.clickup.com/9010076192/v/dc/8cgnph0-14088/8cgnph0-19061
          #
          def execute
            Yousty::Eventsourcing::CommandParamsValidator.call(params[:commands])
            deserialize_commands = Yousty::Eventsourcing::CommandsDeserializer.call(params[:commands])
            expanded_commands = expand_commands(deserialize_commands)
            return too_many_inline_commands if perform_inline? && expanded_commands.size > MAX_INLINE_COMMANDS_PER_REQ

            Yousty::Eventsourcing::CommandsAuthorizer.call(expanded_commands, auth_data)
            Yousty::Eventsourcing::CommandsValidator.call(expanded_commands)
            cmd_bus_response = Yes::Core::CommandBus.new.call(
              add_identity_id_to_command_metadata(deserialize_commands),
              notifier_options: { channel: @channel }
            )

            render json: success_response_data(cmd_bus_response), status: :ok
          end

          private

          def inline_processing_supported?
            Gem::Specification.find_by_name('yousty-eventsourcing').version >= Gem::Version.new('13.3.0')
          end

          def perform_inline?
            (inline_processing_supported? && params[:async] && params[:async] != 'true') ||
              Yousty::Eventsourcing.config.process_commands_inline
          end

          def command_bus
            return Yousty::Eventsourcing::CommandBus.new unless perform_inline?

            Yousty::Eventsourcing::CommandBus.new(perform_inline: perform_inline?)
          end

          def too_many_inline_commands
            error = "Too many commands. You can process up to #{MAX_INLINE_COMMANDS_PER_REQ} commands inline."
            render json: { error: }, status: :unprocessable_entity
          end

          def expand_commands(deserialize_commands)
            deserialize_commands.map do |command|
              command.is_a?(Yousty::Eventsourcing::CommandGroup) ? command.commands : command
            end.flatten
          end

          def add_identity_id_to_command_metadata(commands)
            commands.map do |command|
              command.class.new(
                command.to_h.merge(metadata: (command.metadata || {}).merge(identity_id: auth_data[:identity_id]))
              )
            end
          end

          def transaction_details
            Yousty::Eventsourcing::TransactionDetails.new(
              name: params['transaction_name'] || 'Command batch processing',
              caller_id: auth_data[:identity_id],
              caller_type: 'User'
            )
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

          def jwt_token_error_response(error)
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
            return if @channel.present?

            render json: { title: '"channel" param is required' }, status: :bad_request
          end
        end
      end
    end
  end
end
