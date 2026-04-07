# frozen_string_literal: true

RSpec.describe Yes::Core::ReadModel::Builder do
  let(:builder_class) { Dummy::ReadModels::JobApp::Builder }

  describe 'READ_MODEL_CLASS_REGEXP' do
    subject { builder_class::READ_MODEL_CLASS_REGEXP.match(class_name) }

    shared_examples 'extract correct context, version, aggregate' do
      it 'returns correct values' do
        aggregate_failures do
          expect(subject[:context]).to eq(expected_context)
          expect(subject[:version]).to eq(expected_version)
          expect(subject[:aggregate]).to eq(expected_aggregate)
        end
      end
    end

    context 'when no version' do
      let(:class_name) { 'Dummy::ReadModels::JobApp' }
      let(:expected_context) { 'Dummy' }
      let(:expected_version) { nil }
      let(:expected_aggregate) { 'JobApp' }

      it_behaves_like 'extract correct context, version, aggregate'
    end

    context 'when there is version' do
      let(:class_name) { 'Dummy::ReadModels::V2::JobApp' }
      let(:expected_context) { 'Dummy' }
      let(:expected_version) { 'V2' }
      let(:expected_aggregate) { 'JobApp' }

      it_behaves_like 'extract correct context, version, aggregate'
    end
  end

  describe '.new' do
    subject { builder_class.new }

    context 'when the builder class structure is correct' do
      it 'does not raise an exception' do
        expect { subject }.to_not raise_error
      end
    end

    context 'when the builder class structure is incorrect' do
      let(:builder_class) { Dummy::InvalidModuleStructure::JobApp::Builder }

      it 'raises the InvalidReadModelBuilderClass exception' do
        expect { subject }.to raise_error(described_class::InvalidReadModelBuilderClass)
      end
    end
  end

  describe '#call' do
    context 'when read_model is passed explicitly' do
      subject { builder_class.new.call(event, read_model:) }

      let(:aggregate_id) { SecureRandom.uuid }
      let(:event_data) { { 'job_app_id' => aggregate_id } }
      let(:event_type) { 'SomeEvent' }
      let(:event) { double('SomeEvent', data: event_data, type: event_type, ps_fields_with_values: [], metadata: {}, created_at: nil) }
      let(:read_model_instance) { JobApp.new }
      let(:read_model) { read_model_instance }
      let(:handler_class) { Dummy::ReadModels::JobApp::OnSomeEvent }
      let(:handler) { handler_class.new(event) }

      before do
        allow(handler_class).to receive(:new).with(instance_of(read_model_instance.class)).and_return(handler)
        allow(handler).to receive(:call).with(event).and_call_original
      end

      context 'when event without context' do
        it 'calls the event handler' do
          subject

          expect(handler).to have_received(:call).with(event)
        end
      end

      context 'when event has context' do
        let(:event_context) { 'DummyContext' }
        let(:event_type) { "#{event_context}::SomeEvent" }

        context 'when the handler is defined without a context and with context for the same event' do
          let(:handler_class) { Dummy::ReadModels::JobApp::DummyContext::OnSomeEvent }

          it 'calls the event handler with context' do
            subject

            expect(handler).to have_received(:call).with(event)
          end
        end

        context 'when the handler is defined without a context' do
          let(:event_type) { "#{event_context}::SomeOtherEvent" }
          let(:handler_class) { Dummy::ReadModels::JobApp::OnSomeOtherEvent }

          it 'calls the event handler' do
            subject

            expect(handler).to have_received(:call).with(event)
          end
        end

        context 'when the handler is defined with a context' do
          let(:handler_class) { Dummy::ReadModels::JobApp::DummyContext::OnSomeEvent }

          it 'calls the event handler' do
            subject

            expect(handler).to have_received(:call).with(event)
          end
        end
      end

      context 'when there is proper event handler' do
        context 'when a read model is not given' do
          let(:read_model) { nil }
          let(:new_read_model) { JobApp.new }

          it 'it creates a read model' do
            expect { subject }.to change { JobApp.count }.by(1)
          end

          context 'when aggregate_id_key is invalid' do
            let(:event_data) { {} }
            let(:missing_read_model_id_error) do
              Yes::Core::ReadModel::Builder::MissingReadModelId
            end

            context 'when is missing in the event data' do
              it 'raises MissingReadModelId' do
                expect { subject }.to raise_error(missing_read_model_id_error)
              end
            end

            context 'when is a symbol' do
              let(:event_data) { { job_app_id: 'de7af93b-a529-4531-83c0-98429178a337' } }

              it 'raises MissingReadModelId' do
                expect { subject }.to raise_error(missing_read_model_id_error)
              end
            end
          end
        end

        context 'when event has locale' do
          let(:locale) { :'de-CH' }
          let(:event_data) do
            { 'aggregate_id_key' => 'some_event', 'locale' => locale }
          end

          before { subject }

          context 'when locale is valid' do
            it 'it uses locale when the handler is called' do
              expect(handler).to have_received(:call).with(event) do
                expect(I18n.locale).to eq locale
              end
            end
          end

          context 'when locale is not valid' do
            let(:locale) { :invalid }

            it 'it does not call the handler' do
              expect(handler).to_not have_received(:call).with(event)
            end
          end
        end

        context 'when event without locale' do
          before do
            allow(I18n).to receive(:with_locale).and_call_original

            subject
          end

          it 'calls the handler with default locales' do
            expect(I18n).to have_received(:with_locale).with(I18n.default_locale)
          end
        end
      end

      context 'when there is no event handler defined' do
        let(:error_notifier) { instance_double(Yes::Core::Utils::ErrorNotifier) }
        let(:builder_instance) { builder_class.new }
        let(:event_type) { 'NonExistingEventHandler' }

        before do
          allow(Yes::Core::Utils::ErrorNotifier).to receive(:new) { error_notifier }
          allow(error_notifier).to receive(:event_handler_not_defined)

          subject
        end

        it 'calls ErrorNotifier with event info' do
          expect(error_notifier).to have_received(:event_handler_not_defined)
        end
      end

      context 'when the builder is placed in version namespace' do
        let(:builder_class) { Dummy::ReadModels::V23::NewJobApp::Builder }
        let(:handler_class) { Dummy::ReadModels::V23::NewJobApp::OnSomeEvent }
        let(:read_model) { nil }
        let(:new_read_model) { V23::NewJobApp }
        let(:read_model_instance) { new_read_model.new }
        let(:event_data) { { 'new_job_app_id' => aggregate_id } }

        it 'calls proper read model and proper handler' do
          subject
          expect(handler).to have_received(:call).with(event)
        end
      end
    end

    context 'when read_model is not passed' do
      subject { builder_class.new.call(event) }

      let(:builder_class) { Dummy::ReadModels::Apprenticeship::EventHandlers::Builder }

      let(:event) do
        event = Yes::Core::Event.new(
          type: 'ApprenticeshipPresentation::ApprenticeshipCompanyAssigned',
          data: { company_id:, apprenticeship_id: }
        )
        stream = PgEventstore::Stream.new(
          context: 'ApprenticeshipPresentation', stream_name: 'Apprenticeship', stream_id: apprenticeship_id
        )
        PgEventstore.client.append_to_stream(stream, event)
      end
      let(:company_id) { SecureRandom.uuid }
      let(:apprenticeship_id) { SecureRandom.uuid }

      context 'when related read model record exist' do
        let!(:apprenticeship) { FactoryBot.create(:apprenticeship, id: apprenticeship_id) }

        it 'does not create another one' do
          expect { subject }.not_to(change { Apprenticeship.count })
        end
        it 'processes the given event' do
          expect { subject }.to change { apprenticeship.reload.company_id }.to(company_id)
        end
      end

      context 'when related read model does not exist' do
        it 'creates new one' do
          expect { subject }.to change { Apprenticeship.count }.by(1)
        end
        it 'processes the given event' do
          subject
          expect(Apprenticeship.find(apprenticeship_id).company_id).to eq(company_id)
        end
      end
    end
  end

  describe '#rebuild' do
    subject { builder.rebuild(eventstore: eventstore, id: id) }

    let(:builder) { builder_class.new }
    let(:eventstore) { PgEventstore.client }
    let(:id) { dummy_record.id }
    let(:event1) { instance_spy(Yes::Core::Event, data: { foo: 'Event 1' }) }
    let(:event2) { instance_spy(Yes::Core::Event, data: { foo: 'Event 2' }) }
    let(:event3) { instance_spy(Yes::Core::Event, data: { foo: 'Event 3' }) }
    let(:events) { [event1, event2, event3] }
    let(:response) { events }
    let!(:dummy_record) { JobApp.create }

    context 'when read model already exists' do
      it 'rebuilds read model from events' do
        aggregate_failures do
          expect(eventstore).to receive(:read_paginated).
            with(
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'JobApp', stream_id: id),
              options: { resolve_link_tos: true }
            ).
            and_return([response].to_enum)
          expect(builder).to receive(:call).with(event1, any_args)
          expect(builder).to receive(:call).with(event2, any_args)
          expect(builder).to receive(:call).with(event3, any_args)
        end

        expect { subject }.to(change { dummy_record.reload.created_at })
      end
    end

    context 'when read model does not exist' do
      let(:id) { SecureRandom.uuid }

      it 'rebuilds read model from events' do
        aggregate_failures do
          expect(eventstore).to receive(:read_paginated).
            with(
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'JobApp', stream_id: id),
              options: { resolve_link_tos: true }
            ).
            and_return([response].to_enum)
          expect(builder).to receive(:call).with(event1, any_args)
          expect(builder).to receive(:call).with(event2, any_args)
          expect(builder).to receive(:call).with(event3, any_args)
        end

        expect { subject }.to change { JobApp.where(id: id).count }.by(1)
      end
    end

    context 'when the builder is placed in version namespace' do
      let(:builder_class) { Dummy::ReadModels::V23::NewJobApp::Builder }
      let!(:dummy_record) { V23::NewJobApp.create }
      let(:events) { [event1] }

      before do
        aggregate_failures do
          expect(eventstore).to receive(:read_paginated).
            with(
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'NewJobApp', stream_id: id),
              options: { resolve_link_tos: true }
            ).
            and_return([response].to_enum)
          expect(builder).to receive(:call).with(event1, any_args)
        end
      end

      it 'uses proper read model' do
        expect { subject }.to(change { dummy_record.reload.created_at })
      end
    end
  end

  describe '#aggregate_id_key' do
    subject { builder.aggregate_id_key }

    context 'when the builder is not placed in version namespace' do
      let(:builder) { Dummy::ReadModels::JobApp::Builder.new }

      it 'returns proper aggregate_id_key' do
        expect(subject).to eq('job_app_id')
      end
    end

    context 'when the builder is placed in version namespace' do
      let(:builder) { Dummy::ReadModels::V23::NewJobApp::Builder.new }

      it 'returns proper aggregate_id_key' do
        expect(subject).to eq('new_job_app_id')
      end
    end
  end
end
