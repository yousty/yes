# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Stateless::Handler do
  include EventHelpers

  let(:command_class) do
    Class.new(described_class).tap do |klass|
      klass.event_name = event_name
    end
  end

  let(:handler) { command_class.new(cmd) }

  let(:metadata) { nil }

  let(:cmd) do
    Dummy::Company::Commands::ChangeName::Command.new(name: 'some', company_id: SecureRandom.uuid, metadata:)
  end

  let(:event_name) { 'NameChanged' }

  describe '#call' do
    subject { handler.call }

    let(:event_payload) { {} }
    let(:stream_name) { 'Company' }
    let(:stream) { PgEventstore::Stream.new(context: 'Dummy', stream_name:, stream_id: cmd.company_id) }
    let(:event_attributes) do
      {
        'name' => 'some',
        'company_id' => cmd.company_id
      }
    end

    shared_examples 'publishes event correctly' do
      it 'publishes to proper stream' do
        expect { subject }.to change { safe_read(stream).count }.by(1)
      end

      it 'sets correct attributes' do
        subject

        event = safe_read(stream).last
        expect(event.data).to match(event_attributes)
      end
    end

    context 'when event data not provided' do
      it_behaves_like 'publishes event correctly'
    end

    context 'when event custom payload provided' do
      let(:command_class) do
        event_payload = self.event_payload
        super().tap { _1.define_method(:event_payload) { super().merge(event_payload) } }
      end
      let(:event_payload) { { 'name' => 'something else' } }
      let(:event_attributes) do
        {
          'name' => 'something else',
          'company_id' => cmd.company_id
        }
      end

      it_behaves_like 'publishes event correctly'
    end

    context 'when command is an edit template command' do
      let(:metadata) { { edit_template_command: true } }
      let(:stream_name) { 'CompanyEditTemplate' }

      it_behaves_like 'publishes event correctly'

      it 'sets the correct event type' do
        expect(subject.type).to eq('Dummy::CompanyEditTemplateNameChanged')
      end
    end

    context 'when command is a v1 command' do
      let(:cmd) do
        Dummy::User::Commands::ChangeFirstName::Command.new(name: 'some name', id: SecureRandom.uuid)
      end

      let(:event_name) { 'FirstNameChanged' }
      let(:stream) { PgEventstore::Stream.new(context: 'Dummy', stream_name: 'User', stream_id: cmd.id) }
      let(:event_attributes) do
        {
          'name' => 'some name',
          'id' => cmd.id
        }
      end

      it_behaves_like 'publishes event correctly'
    end

    context 'when event can not be published due to WrongExpectedRevisionError' do
      let(:command_class) do
        Class.new(described_class).tap do |klass|
          klass.event_name = event_name
          klass.streams =
            [
              {
                prefix: 'Dummy::Company',
                subject_key: 'company_id'
              }
            ]
        end
      end

      let(:user_id) { SecureRandom.uuid }
      let(:company_id) { SecureRandom.uuid }
      let(:cmd) do
        Dummy::User::Commands::ChangeFirstName::Command.new(
          id: user_id, name: 'some name', company_id:
        )
      end

      let(:event_name) { 'FirstNameChanged' }
      let(:company_stream) { PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Company', stream_id: company_id) }
      let(:stream) { PgEventstore::Stream.new(context: 'Dummy', stream_name: 'User', stream_id: cmd.id) }
      let(:stream_arrived_events_in_the_meantime) { stream }
      let(:event_attributes) do
        {
          'name' => 'some name',
          'id' => cmd.id
        }
      end

      before do
        allow(handler).to receive(:load_stream_revisions).and_wrap_original do |m, *args|
          result = m.call(*args)

          PgEventstore.client.append_to_stream(
            stream_arrived_events_in_the_meantime, [
              Dummy::SomethingDone.new(data: { 'what' => 'something' })
            ]
          )

          result
        end
      end

      shared_examples 'wrong expected version' do
        it 'raises an error' do
          expect { subject }.to raise_error(PgEventstore::WrongExpectedRevisionError)
        end
      end

      context 'when stream does not exist yet' do
        it_behaves_like 'wrong expected version'

        it 'does not publish command related events' do
          expect do
            subject
          rescue StandardError
            nil
          end.to change { safe_read(stream).count }.from(0).to(1)
        end
      end

      context 'when stream is existing' do
        before do
          PgEventstore.client.append_to_stream(
            stream, [
              Dummy::SomethingDone.new(data: { 'what' => 'something' })
            ]
          )
        end

        it_behaves_like 'wrong expected version'

        it 'does not publish command related events' do
          expect do
            subject
          rescue StandardError
            nil
          end.to change { safe_read(stream).count }.from(1).to(2)
        end
      end

      context 'when events arrived in the meantime to some involved stream' do
        let(:stream_arrived_events_in_the_meantime) { company_stream }

        it_behaves_like 'wrong expected version'

        it 'does not publish event' do
          expect do
            subject
          rescue StandardError
            nil
          end.to_not(change { safe_read(stream).count })
        end
      end
    end

    context 'when OpenTelemetry tracing is enabled' do
      include_context :opentelemetry

      let(:published_event) do
        finished_spans.first.events.find { |it| it.name == 'Event Published to PgEventstore' }
      end
      let(:event) { safe_read(stream).last }

      before do
        Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
      end

      after do
        Yes::Core.configuration.otl_tracer = nil
      end

      it 'includes proper attributes from event in span event' do
        subject

        expect(published_event.attributes).to eq(
          'event.type' => event.type,
          'event.link_id' => '',
          'global_position' => event.global_position,
          'stream' => event.stream.to_json,
          'stream.revision' => event.stream_revision,
          'timestamp_ms' => (event.created_at.to_f * 1000).to_i
        )
      end
    end
  end

  describe 'RevisionsLoader#call' do
    subject { handler.call }

    let(:event_name) { 'NameChanged' }

    let(:user_id) { SecureRandom.uuid }
    let(:company_id) { SecureRandom.uuid }
    let(:team_member_id) { SecureRandom.uuid }

    let(:cmd) do
      Dummy::Company::Commands::StreamRevisionTesting::Command.new(
        user_id:, company_id:, team_member_id:, name: 'some name'
      )
    end

    context 'when streams are not provided' do
      it 'initializes empty stream revisions' do
        subject

        expect(handler.revisions).to eq({})
      end
    end

    context 'when streams are provided' do
      let(:command_class) do
        Class.new(described_class).tap do |klass|
          klass.event_name = event_name
          klass.streams = streams
        end
      end

      let(:streams) do
        [
          {
            prefix: 'Dummy::Apprenticeship',
            subject_key: 'team_member_id'
          },
          {
            prefix: 'Dummy::User',
            subject_key: 'user_id'
          },
          {
            prefix: 'Dummy::Company',
            subject_key: 'company_id'
          }
        ]
      end

      context 'when streams do not exist yet' do
        it 'loads correct revisions' do
          subject
          expect(handler.revisions).to(
            eq(
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Apprenticeship',
                                       stream_id: team_member_id) => nil,
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'User', stream_id: user_id) => nil,
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Company', stream_id: company_id) => nil
            )
          )
        end
      end

      context 'when stream exists and some of them contains events' do
        before do
          PgEventstore.client.append_to_stream(
            PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Apprenticeship', stream_id: team_member_id),
            [
              Dummy::SomethingDone.new(data: { 'what' => 'something' }),
              Dummy::SomethingDone.new(data: { 'what' => 'something else' })
            ]
          )
          PgEventstore.client.append_to_stream(
            PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Company', stream_id: company_id),
            [
              Dummy::SomethingDone.new(data: { 'what' => 'nothing' })
            ]
          )
        end

        it 'initializes properly stream revisions' do
          subject
          expect(handler.revisions).to(
            eq(
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Apprenticeship', stream_id: team_member_id) => 1,
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'User', stream_id: user_id) => nil,
              PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Company', stream_id: company_id) => 0
            )
          )
        end
      end
    end
  end
end
