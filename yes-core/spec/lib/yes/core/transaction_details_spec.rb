# frozen_string_literal: true

RSpec.describe Yes::Core::TransactionDetails do
  shared_examples_for 'continuous transaction' do
    let(:params) { { correlation_id: SecureRandom.uuid, causation_id: SecureRandom.uuid } }

    it 'allows to set only correlation and causation ids for continuous transaction' do
      expect(transaction.causation_id).to eq(params[:causation_id])
      expect(transaction.correlation_id).to eq(params[:correlation_id])
      expect(transaction.to_h).to eq(params)
      expect(transaction.to_h.keys).to contain_exactly(:causation_id, :correlation_id)
    end
  end

  shared_examples_for 'initializable' do
    context 'when full set of params provided' do
      let(:params) do
        {
          name: 'DoSomething',
          correlation_id: SecureRandom.uuid,
          causation_id: SecureRandom.uuid,
          caller_id: SecureRandom.uuid,
          caller_type: 'User'
        }
      end

      it 'initializes first transaction' do
        expect(transaction.to_h).to eq(params)
      end
    end

    context 'when only transaction name is given' do
      let(:params) { { name: 'DoSomething' } }

      it 'sets the default values for attributes' do
        aggregate_failures do
          expect(transaction.name).to eq('DoSomething')
          expect(transaction.caller_id).to be_nil
          expect(transaction.correlation_id).not_to be_nil
          expect(transaction.to_h.keys).to contain_exactly(*%i[name correlation_id])
        end
      end
    end

    context 'when trying to set nil for attributes' do
      let(:params) { { name: 'Do Something', correlation_id: nil } }

      it 'does not allow to explicitly set to correlation' do
        expect { transaction }.to raise_error(Dry::Struct::Error)
      end
    end
  end

  describe '.new' do
    let(:transaction) { described_class.new(params) }

    it_behaves_like 'initializable'

    it_behaves_like 'continuous transaction'
  end

  describe '.from_event' do
    subject { described_class.from_event(sth_happened) }
    let(:sth_happened) do
      Yes::Core::Event.new(id: event_id, metadata: { '$correlationId' => correlation_id })
    end
    let(:event_id) { SecureRandom.uuid }
    let(:correlation_id) { SecureRandom.uuid }

    it 'sets correlation_id from event metadata' do
      expect(subject.correlation_id).to eq(correlation_id)
    end

    it 'sets causation_id from event id' do
      expect(subject.causation_id).to eq(event_id)
    end
  end

  describe '#for_eventstore_metadata' do
    subject { described_class.new(params) }

    let(:params) do
      {
        name: 'DoSomething',
        correlation_id: SecureRandom.uuid,
        causation_id: SecureRandom.uuid,
        caller_id: SecureRandom.uuid,
        caller_type: 'User'
      }
    end

    it 'returns a hash with only correlation_id and causation_id' do
      expect(subject.for_eventstore_metadata).to eq(
        '$correlationId': params[:correlation_id],
        '$causationId': params[:causation_id]
      )
    end
  end
end
