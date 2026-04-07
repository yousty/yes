# frozen_string_literal: true

require_relative '../../../../../rails_helper'

RSpec.describe Yes::Command::Api::Commands::ParamsValidator do
  subject { described_class.call(params) }

  let(:params) { [first_command_params, second_command_params] }

  let(:first_command_params) do
    {
      subject: 'ApprenticeshipPresentation',
      context: 'Activity',
      command: 'DoSomething',
      data: {
        what: 'something'
      }
    }
  end

  let(:second_command_params) do
    {
      subject: 'ApprenticeshipPresentation',
      context: 'Activity',
      command: 'DoSomething',
      data: {
        what: 'something else'
      }
    }
  end

  it 'does not raise any error' do
    expect { subject }.not_to raise_error
  end

  shared_examples 'invalid command params' do
    it 'raises a CommandParamsInvalid error' do
      expect { subject }.to raise_error(
        Yes::Command::Api::Commands::ParamsValidator::CommandParamsInvalid
      )
    end
  end

  context 'when command is missing' do
    let(:second_command_params) { super().except(:command) }

    it_behaves_like 'invalid command params'
  end

  context 'when data is missing' do
    let(:second_command_params) { super().except(:data) }

    it_behaves_like 'invalid command params'
  end

  context 'when context is missing' do
    let(:second_command_params) { super().except(:context) }

    it_behaves_like 'invalid command params'
  end

  context 'when subject is missing' do
    let(:second_command_params) { super().except(:subject) }

    it_behaves_like 'invalid command params'
  end

  context 'when params is not an array' do
    let(:params) { {} }

    it_behaves_like 'invalid command params'
  end

  context 'when command is a command group' do
    context 'when command params are valid' do
      let(:company_id) { SecureRandom.uuid }
      let(:user_id) { SecureRandom.uuid }

      let(:params) do
        [
          {
            subject: 'Company',
            context: 'Dummy',
            command: 'DoSomethingCompounded',
            data: {}
          }
        ]
      end

      it 'does not raise any error' do
        expect { subject }.not_to raise_error
      end
    end
  end
end
