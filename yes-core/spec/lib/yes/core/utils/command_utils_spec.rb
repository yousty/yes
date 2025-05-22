# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::CommandUtils do
  subject(:instance) { described_class.new(context:, aggregate:, aggregate_id:) }

  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:aggregate_id) { SecureRandom.uuid }

  describe '#build_command' do
    subject { instance.build_command(command_name, payload) }

    let(:command_name) { :approve_documents }
    let(:payload) { { document_ids: 'xyz,abc', another: 'xyz' } }
    let(:command_class) { Test::User::Commands::ApproveDocuments::Command }

    it 'builds a command with the correct payload' do
      aggregate_failures do
        expect(subject).to be_a(command_class)
        expect(subject.user_id).to eq(aggregate_id)
      end
    end

    context 'when command class is not found' do
      let(:command_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Command class not found for nonexistent')
      end
    end
  end

  describe '#build_attribute_command' do
    subject { instance.build_attribute_command(attribute_name, payload) }

    let(:attribute_name) { :test_field }
    let(:payload) { { test_field: 'test value' } }
    let(:command_class) { Test::User::Commands::ChangeTestField::Command }

    before do
      # Add test_field attribute to the aggregate
      Test::User::Aggregate.attribute :test_field, :string, command: true
    end

    after do
      # Clean up test_field attribute
      Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                  Test::User::Aggregate.attributes.except(:test_field))
    end

    it 'builds a command with the correct payload' do
      aggregate_failures do
        expect(subject).to be_a(command_class)
        expect(subject.user_id).to eq(aggregate_id)
        expect(subject.test_field).to eq('test value')
      end
    end

    context 'when command class is not found' do
      let(:attribute_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Command class not found for change_nonexistent')
      end
    end

    context 'with aggregate attribute id command' do
      let(:attribute_name) { :location_id }
      let(:location_id) { SecureRandom.uuid }
      let(:payload) { { location_id: location_id } }
      let(:command_class) { Test::User::Commands::ChangeLocationId::Command }

      before do
        # Add location attribute to the aggregate
        Test::User::Aggregate.attribute :location_id, :uuid, command: true
      end

      after do
        # Clean up location attribute
        Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                    Test::User::Aggregate.attributes.except(:location_id))
      end

      it 'builds a command with the correct payload using the base command name' do
        aggregate_failures do
          expect(subject).to be_a(command_class)
          expect(subject.user_id).to eq(aggregate_id)
          expect(subject.location_id).to eq(location_id)
        end
      end
    end
  end

  describe '#fetch_guard_evaluator_class' do
    subject { instance.fetch_guard_evaluator_class(command_name) }

    let(:command_name) { :approve_documents }
    let(:guard_evaluator_class) { Test::User::Commands::ApproveDocuments::GuardEvaluator }

    it 'returns the correct guard evaluator class' do
      expect(subject).to eq(guard_evaluator_class)
    end

    context 'when guard evaluator class is not found' do
      let(:command_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Guard evaluator class not found for nonexistent')
      end
    end
  end

  describe '#build_event' do
    subject { instance.build_event(command_name:, payload:, metadata:) }

    let(:command_name) { :approve_documents }
    let(:user_id) { SecureRandom.uuid }
    let(:payload) do
      {
        user_id:,
        another: 'value',
        document_ids: 'xyz,abc'
      }
    end
    let(:metadata) { { user_id: } }
    let(:event_class) { Test::User::Events::DocumentsApproved }

    before do
      allow(Yes::Core.configuration).to receive(:event_classes_for_command).
        with(context, aggregate, command_name).
        and_return([event_class])
    end

    it 'builds an event with the correct attributes' do
      aggregate_failures do
        expect(subject).to be_a(event_class)
        expect(subject.type).to eq('Test::UserDocumentsApproved')
        expect(subject.data).to eq(payload)
        expect(subject.metadata).to eq(metadata)
      end
    end
  end

  describe '#build_stream' do
    subject { instance.build_stream(**params) }

    context 'with default parameters' do
      let(:params) { {} }

      it 'builds a stream with instance defaults' do
        aggregate_failures do
          expect(subject).to be_a(PgEventstore::Stream)
          expect(subject.context).to eq(context)
          expect(subject.stream_name).to eq(aggregate)
          expect(subject.stream_id).to eq(aggregate_id)
        end
      end
    end

    context 'with custom parameters' do
      let(:custom_context) { 'CustomContext' }
      let(:custom_name) { 'CustomName' }
      let(:custom_id) { SecureRandom.uuid }
      let(:params) do
        {
          context: custom_context,
          name: custom_name,
          id: custom_id
        }
      end

      it 'builds a stream with provided parameters' do
        aggregate_failures do
          expect(subject).to be_a(PgEventstore::Stream)
          expect(subject.context).to eq(custom_context)
          expect(subject.stream_name).to eq(custom_name)
          expect(subject.stream_id).to eq(custom_id)
        end
      end
    end
  end

  describe '#stream_revision' do
    subject { instance.stream_revision(stream) }

    let(:stream) { instance.build_stream }
    let(:client) { PgEventstore.client }
    let(:event) { instance_double(PgEventstore::Event, stream_revision: 42) }

    before do
      allow(PgEventstore).to receive(:client).and_return(client)
    end

    context 'when stream exists with events' do
      before do
        allow(client).to receive(:read).
          with(stream, options: { direction: 'Backwards', max_count: 1 }, middlewares: []).
          and_return([event])
      end

      it { is_expected.to eq(42) }
    end

    context 'when stream exists but has no events' do
      before do
        allow(client).to receive(:read).
          with(stream, options: { direction: 'Backwards', max_count: 1 }, middlewares: []).
          and_return([])
      end

      it { is_expected.to eq(0) }
    end

    context 'when stream does not exist' do
      before do
        allow(client).to receive(:read).
          and_raise(PgEventstore::StreamNotFoundError.new('Stream not found'))
      end

      it { is_expected.to eq(:no_stream) }
    end
  end

  describe '#prepare_payload' do
    subject { instance.prepare_payload(attribute, payload) }

    context 'when payload is already a hash' do
      let(:attribute) { :test_field }
      let(:payload) { { key: 'value', another_key: 'another_value' } }

      it 'returns the payload unchanged' do
        expect(subject).to eq(payload)
      end
    end

    context 'when payload is not a hash' do
      let(:attribute) { :test_field }
      let(:payload) { 'test_value' }

      it 'wraps the payload in a hash with the attribute as key' do
        expect(subject).to eq({ test_field: 'test_value' })
      end
    end
  end
end
