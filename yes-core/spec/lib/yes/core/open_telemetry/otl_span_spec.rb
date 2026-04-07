# frozen_string_literal: true

RSpec.describe Yes::Core::OpenTelemetry::OtlSpan do
  include_context :opentelemetry

  describe '#otl_span' do
    subject { instance.otl_span(event, &given_block) }

    let(:instance) { described_class.new(otl_data:, otl_tracer:) }

    let(:event) { Yes::Core::Event.new(metadata:) }

    let(:metadata) { {} }

    let(:given_block) { nil }

    let(:otl_tracer) { OpenTelemetry.tracer_provider.tracer('SpecTracer') }
    let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new }

    describe 'span name' do
      context 'when custom span name is not provided' do
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_name) { ['UnknownName'] }
        end
      end

      context 'when custom span name is provided' do
        let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name:) }
        let(:span_name) { 'MyCustomSpan' }

        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_name) { [span_name] }
        end
      end
    end

    describe 'span kind' do
      context 'when span kind is not provided' do
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_kind) { [:internal] }
        end
      end

      context 'when span kind is provided' do
        let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_kind: :consumer) }

        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_kind) { [:consumer] }
        end
      end
    end

    describe 'span attributes' do
      context 'when there is no custom attributes provided' do
        it_behaves_like 'open telemetry trackable'
      end

      context 'when there are custom attributes provided' do
        let(:otl_data) do
          Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(
            span_attributes: { 'custom_attribute' => 'custom_value' }
          )
        end

        it_behaves_like 'open telemetry trackable' do
          let(:extra_attribute_keys) { { 'UnknownName' => { 'custom_attribute' => 'custom_value' } } }
        end
      end
    end

    describe 'track_sql' do
      context 'when track_sql is not provided' do
        context 'when block is not given' do
          it_behaves_like 'open telemetry trackable'

          it 'does not subscribe to the sql.active_record' do
            expect(ActiveSupport::Notifications).not_to receive(:subscribed)

            subject
          end
        end

        context 'when block is given' do
          let(:given_block) { -> { ActiveRecord::Base.connection.execute('SELECT 1;') } }

          it_behaves_like 'open telemetry trackable'

          it 'does not subscribe to the sql.active_record' do
            expect(ActiveSupport::Notifications).not_to receive(:subscribed)

            subject
          end
        end
      end

      context 'when track_sql is true for the current span' do
        let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(track_sql: true) }

        context 'when block is not given' do
          let(:given_block) { nil }

          it_behaves_like 'open telemetry trackable' do
            let(:expected_attributes_array) { [{ 'UnknownName' => { 'track_sql' => true, 'root_track_sql' => false } }] }
          end

          it 'does not subscribe to the sql.active_record' do
            expect(ActiveSupport::Notifications).not_to receive(:subscribed)

            subject
          end
        end

        context 'when block is given' do
          context 'when inside block SQL queries were executed' do
            let(:given_block) do
              lambda {
                TestUser.last
                SharedProfileReadModel.last
              }
            end

            it_behaves_like 'open telemetry trackable' do
              let(:expected_spans_amount) { 3 }
              let(:expected_spans_kind) { %i[internal internal internal] }
              let(:expected_spans_name) { ['SQL TestUser Load', 'SQL SharedProfileReadModel Load', 'UnknownName'] }
              let(:expected_attributes_array) do
                [
                  { 'UnknownName' => { 'track_sql' => true, 'root_track_sql' => false } },
                  {
                    'SQL TestUser Load' => {
                      'db.binds' => a_string_matching(/LIMIT/),
                      'db.statement' => a_string_matching(/test_users/),
                      'db.system' => 'postgresql',
                      'db.event_name' => 'TestUser Load'
                    }
                  },
                  {
                    'SQL SharedProfileReadModel Load' => {
                      'db.binds' => a_string_matching(//),
                      'db.statement' => a_string_matching(/shared_profile_read_models/),
                      'db.system' => 'postgresql',
                      'db.event_name' => 'SharedProfileReadModel Load'
                    }
                  }
                ]
              end
            end

            it 'subscribes to the sql.active_record' do
              expect(ActiveSupport::Notifications).to receive(:subscribed)

              subject
            end
          end

          context 'when inside block SQL query was not executed' do
            let(:given_block) { -> { 'some value' } }

            it_behaves_like 'open telemetry trackable' do
              let(:extra_attribute_keys) { { 'UnknownName' => { 'track_sql' => true, 'root_track_sql' => false } } }
            end
          end
        end
      end

      context 'when nested spans' do
        subject do
          otl_tracer.in_span('RootSpan', attributes: { 'track_sql' => false, 'root_track_sql' => root_track_sql }) do
            super()
          end
        end

        let(:root_track_sql) { true }

        context 'when track_sql is true for the root span' do
          let(:root_track_sql) { true }
          let(:given_block) { -> { 'some value' } }

          context 'when track_sql is true for the current span' do
            let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(track_sql: true) }

            it_behaves_like 'open telemetry trackable' do
              let(:expected_spans_amount) { 2 }
              let(:expected_spans_kind) { %i[internal internal] }
              let(:expected_spans_name) { %w[RootSpan UnknownName] }
              let(:expected_attributes_array) { [{ 'UnknownName' => { 'track_sql' => true, 'root_track_sql' => true } }] }
            end

            it 'does not subscribe again to the sql.active_record' do
              expect(ActiveSupport::Notifications).not_to receive(:subscribed)

              subject
            end
          end

          context 'when track_sql is false for the current span' do
            let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(track_sql: false) }

            it_behaves_like 'open telemetry trackable' do
              let(:expected_spans_amount) { 2 }
              let(:expected_spans_kind) { %i[internal internal] }
              let(:expected_spans_name) { %w[RootSpan UnknownName] }
              let(:expected_attributes_array) { [{ 'UnknownName' => { 'track_sql' => false, 'root_track_sql' => true } }] }
            end

            it 'does not subscribe to the sql.active_record' do
              expect(ActiveSupport::Notifications).not_to receive(:subscribed)

              subject
            end
          end
        end

        context 'when track_sql is false for the root span' do
          let(:root_track_sql) { false }
          let(:given_block) { -> { TestUser.last } }

          context 'when track_sql is true for the current span' do
            let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(track_sql: true) }

            it_behaves_like 'open telemetry trackable' do
              let(:expected_spans_amount) { 3 }
              let(:expected_spans_kind) { %i[internal internal internal] }
              let(:expected_spans_name) { ['RootSpan', 'SQL TestUser Load', 'UnknownName'] }
              let(:expected_attributes_array) { [{ 'UnknownName' => { 'track_sql' => true, 'root_track_sql' => false } }] }
            end

            it 'subscribes the sql.active_record' do
              expect(ActiveSupport::Notifications).to receive(:subscribed).once

              subject
            end
          end

          context 'when track_sql is false for the current span' do
            let(:otl_data) { Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(track_sql: false) }

            it_behaves_like 'open telemetry trackable' do
              let(:expected_spans_amount) { 2 }
              let(:expected_spans_kind) { %i[internal internal] }
              let(:expected_spans_name) { %w[RootSpan UnknownName] }
              let(:expected_attributes_array) { [{ 'UnknownName' => { 'track_sql' => false, 'root_track_sql' => false } }] }
            end

            it 'does not subscribe to the sql.active_record' do
              expect(ActiveSupport::Notifications).not_to receive(:subscribed)

              subject
            end
          end
        end
      end
    end

    describe 'links' do
      shared_examples 'no links' do
        it 'does not create links' do
          subject

          expect(in_memory_exporter.finished_spans.first.links).to be_empty
        end
      end

      context 'when there are no links extractor' do
        it_behaves_like 'open telemetry trackable'
        it_behaves_like 'no links'
      end

      context 'when the links extractor was provided' do
        let(:otl_data) do
          Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(
            links_extractor: ->(event, **) { event.metadata['otl_context'] }
          )
        end

        context 'when there are no links to be extracted' do
          it_behaves_like 'open telemetry trackable'
          it_behaves_like 'no links'
        end

        context 'when there are links to be extracted' do
          let(:metadata) do
            { 'otl_context' => { 'root_context' => { 'traceparent' => '00-12345678901234567890123456789012-1234567890123456-01' } } }
          end

          it_behaves_like 'open telemetry trackable'
          it 'creates a proper links' do
            subject

            aggregate_failures do
              links = in_memory_exporter.finished_spans.first.links

              expect(links).to be_present
              expect(links.first.span_context.trace_id.unpack1('H*')).to eq('12345678901234567890123456789012')
              expect(links.first.span_context.span_id.unpack1('H*')).to eq('1234567890123456')
            end
          end
        end
      end
    end
  end
end
