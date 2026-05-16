# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::GroupPayloadNormalizer do
  subject(:result) do
    described_class.call(
      params,
      command_contexts: command_contexts,
      own_context_subjects: own_context_subjects,
      own_context: own_context,
      own_subject: own_subject
    )
  end

  let(:command_contexts) { %i[dummy] }
  let(:own_context_subjects) { %i[company user] }
  let(:own_context) { :dummy }
  let(:own_subject) { :company }

  context 'with reserved keys' do
    let(:params) do
      {
        transaction: nil,
        origin: 'cli',
        batch_id: SecureRandom.uuid,
        metadata: { 'foo' => 'bar' },
        command_id: SecureRandom.uuid,
        es_encrypted: false,
        company: { name: 'Acme' }
      }
    end

    it 'strips reserved keys from the result' do
      expect(result).to eq(dummy: { company: { name: 'Acme' } })
    end
  end

  context 'with subject-nested form (keys are own-context subjects)' do
    let(:params) do
      {
        company: { name: 'Acme', description: 'best' },
        user: { first_name: 'Ada' }
      }
    end

    it 'groups each subject under the own context' do
      expect(result).to eq(
        dummy: {
          company: { name: 'Acme', description: 'best' },
          user: { first_name: 'Ada' }
        }
      )
    end
  end

  context 'with flat form (keys are aggregate attributes)' do
    let(:params) { { name: 'Acme', description: 'best' } }

    it 'nests them under own_context.own_subject' do
      expect(result).to eq(dummy: { company: { name: 'Acme', description: 'best' } })
    end
  end

  context 'with context-nested form (key matches a command context)' do
    let(:command_contexts) { %i[dummy billing] }
    let(:params) do
      {
        billing: { invoice: { number: 'INV-1' } },
        company: { name: 'Acme' }
      }
    end

    it 'passes context-keyed value through verbatim and groups others normally' do
      expect(result).to eq(
        billing: { invoice: { number: 'INV-1' } },
        dummy: { company: { name: 'Acme' } }
      )
    end
  end

  context 'with mixed forms (flat + subject + context)' do
    let(:command_contexts) { %i[dummy billing] }
    let(:params) do
      {
        billing: { invoice: { number: 'INV-1' } },
        user: { first_name: 'Ada' },
        name: 'Acme'
      }
    end

    it 'distributes each key according to its match' do
      expect(result).to eq(
        billing: { invoice: { number: 'INV-1' } },
        dummy: {
          user: { first_name: 'Ada' },
          company: { name: 'Acme' }
        }
      )
    end
  end

  context 'when params is empty' do
    let(:params) { {} }

    it 'returns an empty hash' do
      expect(result).to eq({})
    end
  end
end
