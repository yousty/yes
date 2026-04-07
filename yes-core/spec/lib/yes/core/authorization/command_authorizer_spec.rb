# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::CommandAuthorizer do
  describe '.call' do
    subject { described_class.call(command, auth_data) }

    let(:auth_data) { { identity_id: } }
    let(:identity_id) { SecureRandom.uuid }
    let(:command) do
      Dummy::Activity::Commands::DoSomething::Command.new(what: 'something', id: SecureRandom.uuid)
    end

    context 'when user is admin' do
      around do |example|
        original = Yes::Core.configuration.super_admin_check
        Yes::Core.configuration.super_admin_check = ->(_auth_data) { true }
        example.run
        Yes::Core.configuration.super_admin_check = original
      end

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when user is not admin' do
      it 'raises CommandNotAuthorized error' do
        expect { subject }.to(
          raise_error(Yes::Core::Authorization::CommandAuthorizer::CommandNotAuthorized)
        )
      end
    end
  end
end
