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

    context 'with edit_template_command metadata' do
      let(:metadata) { { user_id:, edit_template_command: true } }

      it 'builds an event with EditTemplate in the type' do
        aggregate_failures do
          expect(subject).to be_a(event_class)
          expect(subject.type).to eq('Test::UserEditTemplateDocumentsApproved')
          expect(subject.data).to eq(payload)
          expect(subject.metadata).to eq(metadata)
        end
      end
    end

    context 'with draft metadata' do
      let(:metadata) { { user_id:, draft: true } }

      it 'builds an event with Draft in the type' do
        aggregate_failures do
          expect(subject).to be_a(event_class)
          expect(subject.type).to eq('Test::UserDraftDocumentsApproved')
          expect(subject.data).to eq(payload)
          expect(subject.metadata).to eq(metadata)
        end
      end
    end

    context 'when the aggregate class is draftable with a custom changes_read_model' do
      let(:aggregate) { 'Recruiter' }
      let(:draftable_aggregate_class) do
        Class.new do
          def self._changes_read_model_explicit
            true
          end

          def self.changes_read_model_name
            'user_edit_template'
          end
        end
      end

      before do
        stub_const('Test::Recruiter::Aggregate', draftable_aggregate_class)
        allow(Yes::Core.configuration).to receive(:event_classes_for_command).
          with(context, aggregate, command_name).
          and_return([event_class])
      end

      context 'with edit_template_command metadata' do
        let(:metadata) { { user_id:, edit_template_command: true } }

        it 'uses the camelized changes_read_model_name as the type prefix' do
          expect(subject.type).to eq('Test::UserEditTemplateDocumentsApproved')
        end
      end

      context 'with draft metadata' do
        let(:metadata) { { user_id:, draft: true } }

        it 'still uses the camelized changes_read_model_name (DSL config wins over flag)' do
          expect(subject.type).to eq('Test::UserEditTemplateDocumentsApproved')
        end
      end

      context 'without draft or edit_template_command metadata' do
        it 'leaves the aggregate name unchanged' do
          expect(subject.type).to eq('Test::RecruiterDocumentsApproved')
        end
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

    context 'with draft metadata against a draftable class with a custom changes_read_model' do
      let(:aggregate) { 'Recruiter' }
      let(:draftable_aggregate_class) do
        Class.new do
          def self._changes_read_model_explicit
            true
          end

          def self.changes_read_model_name
            'user_edit_template'
          end
        end
      end

      before { stub_const('Test::Recruiter::Aggregate', draftable_aggregate_class) }

      context 'with edit_template_command metadata' do
        let(:params) { { metadata: { edit_template_command: true } } }

        it 'derives the stream name from the camelized changes_read_model_name' do
          expect(subject.stream_name).to eq('UserEditTemplate')
        end
      end

      context 'with draft metadata' do
        let(:params) { { metadata: { draft: true } } }

        it 'derives the stream name from the camelized changes_read_model_name (DSL config wins over flag)' do
          expect(subject.stream_name).to eq('UserEditTemplate')
        end
      end
    end

    context 'with draft metadata against a non-draftable class' do
      let(:params) { { metadata: { draft: true } } }

      it 'falls back to the legacy <Aggregate>Draft suffix' do
        expect(subject.stream_name).to eq('UserDraft')
      end
    end

    context 'with edit_template_command metadata against a non-draftable class' do
      let(:params) { { metadata: { edit_template_command: true } } }

      it 'falls back to the legacy <Aggregate>EditTemplate suffix' do
        expect(subject.stream_name).to eq('UserEditTemplate')
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

  describe '#prepare_assign_command_payload' do
    subject { instance.prepare_assign_command_payload(command_name, payload) }
    let(:command_name) { :assign_location }
    let(:location) { Test::Location::Aggregate.new }
    let(:location_id) { location.id }
    let(:payload) { { location: } }

    it 'converts payload with aggregate to payload with UUID' do
      expect(subject).to eq({ location_id: })
    end
  end

  describe '#prepare_default_payload' do
    subject { instance.prepare_default_payload(command_name, payload, Test::User::Aggregate) }
    let(:command_name) { :test_command_with_default_payload }
    let(:payload) { {} }

    context 'when command has only one argument with default value' do
      context 'when the argument is not provided' do
        it 'returns the default value' do
          expect(subject).to eq({ default_payload_test: 'foo' })
        end

        context 'when the default value is a proc' do
          let(:command_name) { :test_dynamic_default }
          let(:time) { DateTime.new(2025, 9, 27, 12, 0, 0) }
          it 'returns the run-time determined default value' do
            # subject is memoized, so we need explicit call for second value
            aggregate_failures do
              allow(Time.zone).to receive(:now).and_return(time)
              expect(subject).to eq({ dynamic_default_test: '2025-09-28 12:00:00' })
              allow(Time.zone).to receive(:now).and_return(time + 1.day)
              second_call = instance.prepare_default_payload(command_name, payload, Test::User::Aggregate)
              expect(second_call).to eq({ dynamic_default_test: '2025-09-29 12:00:00' })
            end
          end
        end
      end

      context 'when the argument is provided' do
        let(:payload) { { default_payload_test: 'bar' } }
        it 'returns the provided value' do
          expect(subject).to eq({ default_payload_test: 'bar' })
        end
      end
    end

    context 'when command has multiple arguments with default values' do
      let(:command_name) { :test_command_with_default_payload_and_other_attribute }
      let(:payload) { { name: 'foo' } }

      context 'when the argument with default value is not provided' do
        it 'returns the default value' do
          expect(subject).to eq({ name: 'foo', default_payload_test: 'bar' })
        end
      end

      context 'when the argument with default value is provided' do
        let(:payload) { { name: 'foo', default_payload_test: 'baz' } }
        it 'returns the provided value' do
          expect(subject).to eq({ name: 'foo', default_payload_test: 'baz' })
        end
      end
    end
  end
end
