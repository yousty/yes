# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yes::Command::Api::Commands::BatchValidator do
  describe '.call' do
    subject { described_class.call(commands) }

    context 'when a command has no validator' do
      let(:commands) do
        [
          Dummy::Commands::Activity::DoSomething.new(
            what: 'something', id: SecureRandom.uuid
          )
        ]
      end

      it 'does not raise error' do
        expect { subject }.to_not raise_error
      end
    end

    context 'when all commands are valid' do
      let(:commands) do
        [
          Dummy::Commands::Activity::DoSomething.new(
            what: 'something', id: SecureRandom.uuid
          ),
          Dummy::Commands::Activity::DoSomethingElse.new(
            what: 'something else', id: SecureRandom.uuid
          ),
          Dummy::Actions::Commands::DoSomething::Command.new(
            what: 'something v2', id: SecureRandom.uuid
          )
        ]
      end

      it 'does not raise any error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when some commands are not valid' do
      let(:invalid_command_id) { SecureRandom.uuid }
      let(:invalid_command_metadata) { { 'meta' => 'data' } }
      let(:invalid_command_payload) { { id: SecureRandom.uuid, what: 'something invalid' } }
      let(:invalid_command_attributes) do
        invalid_command_payload.merge({ metadata: invalid_command_metadata, command_id: invalid_command_id })
      end

      let(:commands) do
        [
          Dummy::Commands::Activity::DoSomething.new(
            what: 'something', id: SecureRandom.uuid
          ),
          Dummy::Commands::Activity::DoSomethingElse.new(
            what: 'something else', id: SecureRandom.uuid
          ),
          Dummy::Commands::Activity::DoSomethingInvalid.new(
            invalid_command_attributes
          )
        ]
      end

      it 'raises proper CommandsInvalid error' do
        expect { subject }.to raise_error do |error|
          aggregate_failures do
            expect(error).to be_a(Yes::Command::Api::Commands::BatchValidator::CommandsInvalid)
            expect(error.extra).to match_array(
              [
                {
                  message: 'Command is invalid',
                  command: 'Dummy::Commands::Activity::DoSomethingInvalid',
                  command_id: invalid_command_id,
                  data: invalid_command_payload,
                  metadata: invalid_command_metadata,
                  details: { foo: :bar }
                }
              ]
            )
          end
        end
      end
    end

    context 'when some v2 commands are not valid' do
      let(:invalid_command_id) { SecureRandom.uuid }
      let(:invalid_command_metadata) { { 'meta' => 'data' } }
      let(:invalid_command_payload) { { id: SecureRandom.uuid, what: 'something invalid v2' } }
      let(:invalid_command_attributes) do
        invalid_command_payload.merge({ metadata: invalid_command_metadata, command_id: invalid_command_id })
      end

      let(:commands) do
        [
          Dummy::Commands::Activity::DoSomething.new(
            what: 'something', id: SecureRandom.uuid
          ),
          Dummy::Commands::Activity::DoSomethingElse.new(
            what: 'something else', id: SecureRandom.uuid
          ),
          Dummy::Actions::Commands::DoSomethingInvalid::Command.new(
            invalid_command_attributes
          )
        ]
      end

      it 'raises proper CommandsInvalid error' do
        expect { subject }.to raise_error do |error|
          aggregate_failures do
            expect(error).to be_a(Yes::Command::Api::Commands::BatchValidator::CommandsInvalid)
            expect(error.extra).to match_array(
              [
                {
                  message: 'V2 Command is invalid',
                  command: 'Dummy::Actions::Commands::DoSomethingInvalid::Command',
                  command_id: invalid_command_id,
                  data: invalid_command_payload,
                  metadata: invalid_command_metadata,
                  details: nil
                }
              ]
            )
          end
        end
      end
    end

    context 'when a v2 command has no validator' do
      let(:commands) do
        [
          Dummy::Actions::Commands::DoSomethingElse::Command.new(
            what: 'something else v2', id: SecureRandom.uuid
          )
        ]
      end

      it 'does not raise error' do
        expect { subject }.to_not raise_error
      end
    end
  end
end
