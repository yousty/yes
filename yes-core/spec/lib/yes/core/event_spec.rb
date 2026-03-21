# frozen_string_literal: true

RSpec.describe Yes::Core::Event do
  let(:instance) { described_class.new }

  it { is_expected.to be_a(PgEventstore::Event) }

  describe '#initialize' do
    subject { described_class.new(**data) }
    let(:data) { { foo: 'bar', bar: 'foo' } }

    it 'has stringified keys' do
      expect(subject.data.keys).to all be_a(String)
    end
  end

  describe '#as_json' do
    subject { instance.as_json }

    it { is_expected.to be_a(Hash) }
    it 'has stringified keys' do
      expect(subject.keys).to all be_a(String)
    end
  end

  describe '#to_json' do
    subject { instance.to_json }

    it { is_expected.to be_a(String) }
    it 'generates correct json' do
      expect { JSON.parse(subject) }.not_to raise_error
    end

    describe 'rails compatibility' do
      subject { { event: instance }.to_json }

      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe '#encrypted?' do
    subject { instance.encrypted? }

    context 'when "encryption" key is present in the metadata' do
      before do
        instance.metadata['encryption'] = {}
      end

      context 'when its value is empty' do
        it { is_expected.to eq(false) }
      end

      context 'when its value is present' do
        before do
          instance.metadata['encryption'] = { 'foo' => 'bar' }
        end

        it { is_expected.to eq(true) }
      end
    end

    context 'when "encryption" key is absent' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#ps_fields_with_values' do
    subject { instance.ps_fields_with_values }

    context 'when event has no payload store fields' do
      let(:instance) { Dummy::SomethingDone.new(data: { 'what' => 'xyz' }) }

      it { is_expected.to eq({}) }
    end

    context 'when event has some payload store fields' do
      let(:user_id) { SecureRandom.uuid }
      let(:text) { "payload-store:#{SecureRandom.uuid}" }
      let(:data) { "payload-store:#{SecureRandom.uuid}" }

      let(:instance) do
        described_class.new(data: { 'user_id' => user_id, 'text' => text, 'data' => data })
      end

      it { is_expected.to eq({ 'data' => data, 'text' => text }) }
    end

    context 'when event has some payload store fields like array or hash' do
      let(:user_id) { SecureRandom.uuid }
      let(:data) { "payload-store:#{SecureRandom.uuid}" }
      let(:reason) { { 'type' => 'skipped' } }
      let(:names) { %w[name_1 name_2] }

      let(:instance) do
        described_class.new(
          data: { 'user_id' => user_id, 'data' => data, 'reason' => reason, 'names' => names }
        )
      end

      it { is_expected.to eq({ 'data' => data }) }
    end

    context 'when payload store fields already resolved' do
      let(:user_id) { SecureRandom.uuid }
      let(:text) { 'resolved' }
      let(:data) { 'plain value' }

      let(:instance) do
        described_class.new(
          data: { 'user_id' => user_id, 'text' => text, 'data' => data }
        )
      end

      it { is_expected.to eq({}) }
    end
  end

  describe 'schema validation' do
    subject { event_class.new(data:) }

    let(:event_class) { described_class }
    let(:data) { { foo: 'bar' } }

    context 'when schema is not defined' do
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when schema is defined' do
      let(:event_class) do
        Class.new(described_class) do
          def schema
            Dry::Schema.Params do
              required(:baz).filled(:string)
            end
          end
        end
      end

      context 'when schema is invalid' do
        it 'raises error' do
          expect { subject }.to raise_error(described_class::InvalidDataError)
        end
      end

      context 'when schema is valid' do
        let(:data) { { baz: 'bar' } }

        it 'does not raise error' do
          expect { subject }.not_to raise_error
        end
      end
    end

    context 'when schema contains payload store field' do
      let(:event_class) do
        Class.new(described_class) do
          payload_store_fields :baz

          def schema
            Dry::Schema.Params do
              required(:baz).hash do
                required(:foo).filled(:string)
              end
            end
          end
        end
      end

      context 'when schema is invalid' do
        it 'raises error' do
          expect { subject }.to raise_error(described_class::InvalidDataError)
        end
      end

      context 'when payload store field contains valid data' do
        let(:data) { { baz: { foo: 'something' } } }

        it 'does not raise error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when payload store field contains payload store id' do
        let(:data) { { baz: "#{described_class::PAYLOAD_STORE_VALUE_PREFIX}#{SecureRandom.uuid}" } }

        it 'does not raise error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when payload store field contains invalid payload store id' do
        let(:data) { { baz: "#{described_class::PAYLOAD_STORE_VALUE_PREFIX}123" } }

        it 'raises error' do
          expect { subject }.to raise_error(described_class::InvalidDataError)
        end
      end
    end
  end
end
