# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::GuardRunner do
  subject(:guard_runner) { described_class.new(aggregate) }

  let(:aggregate_id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }
  let!(:read_model) { TestUser.create!(id: aggregate_id, name: 'John') }
  let(:aggregate) { Test::User::Aggregate.new(aggregate_id) }

  describe '#call' do
    subject { guard_runner.call(command, command_name, guard_evaluator_class, skip_guards:) }

    let(:command_name) { :change_name }
    let(:guard_evaluator_class) { Test::User::Commands::ChangeName::GuardEvaluator }
    let(:skip_guards) { false }

    let(:command) do
      Test::User::Commands::ChangeName::Command.new(
        name: 'Jane',
        user_id:
      )
    end

    context 'with passing guards' do
      it 'evaluates guards successfully' do
        result = subject

        aggregate_failures do
          expect(result).to be_a(Test::User::Commands::ChangeName::GuardEvaluator)
          expect(result.accessed_external_aggregates).to eq([])
        end
      end

      it 'clears any existing command error' do
        # Set an error first
        aggregate.change_name_error = 'Previous error'

        subject

        expect(aggregate.change_name_error).to be_nil
      end
    end

    context 'with failing guard' do
      let(:command) do
        Test::User::Commands::ChangeName::Command.new(
          name: 'John', # Same as current value
          user_id:
        )
      end

      it 'raises NoChangeTransition error' do
        expect { subject }.to raise_error(
          Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
          /no_change/
        )
      end

      it 'sets error on aggregate' do
        subject rescue nil

        expect(aggregate.change_name_error).to include('no_change')
      end
    end

    context 'when guards are skipped' do
      let(:skip_guards) { true }

      let(:command) do
        Test::User::Commands::ChangeName::Command.new(
          name: 'John', # Same value - would normally fail no_change guard
          user_id:
        )
      end

      it 'returns nil without evaluating guards' do
        expect(subject).to be_nil
      end

      it 'clears any existing command error' do
        aggregate.change_name_error = 'Previous error'

        subject

        expect(aggregate.change_name_error).to be_nil
      end
    end
  end
end