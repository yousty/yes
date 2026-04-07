# frozen_string_literal: true

RSpec.describe Yes::Core::OpenTelemetry::Trackable do
  include_context :opentelemetry

  let!(:dummy_class) do
    Class.new do
      include Yes::Core::OpenTelemetry::Trackable

      def untracked_method
        'untracked'
      end

      def dummy_method1
        'test1'
      end

      def dummy_method_with_sql(_data)
        TestUser.first

        'test4'
      end
    end
  end

  let(:dummy_instance) { DummyClass.new }

  before do
    stub_const('DummyClass', dummy_class)
  end
  describe '.otl_trackable' do
    subject { dummy_instance.dummy_method1 }

    it_behaves_like 'no open telemetry tracing' do
      before do
        DummyClass.otl_trackable(:dummy_method1)
      end

      let(:returned_result) { 'test1' }
    end

    context 'when a tracer is configured' do
      before do
        Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
      end

      context 'when method is not tracked' do
        subject { dummy_instance.dummy_method1 }

        it_behaves_like 'no open telemetry tracing' do
          let(:returned_result) { 'test1' }
        end
      end

      context 'when otl_data is not provided' do
        subject { dummy_instance.dummy_method1 }

        before do
          DummyClass.otl_trackable(:dummy_method1)
        end

        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_name) { ['DummyClass'] }
          let(:expected_spans_kind) { [:internal] }
          let(:expected_spans_amount) { 1 }
          let(:extra_attribute_keys) { {} }
        end
      end

      context 'when otl_data is provided' do
        context 'when span_name is not provided' do
          subject { dummy_instance.dummy_method1 }

          before do
            DummyClass.otl_trackable :dummy_method1, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(
              span_kind: :client,
              span_attributes: { 'test' => 'test' }
            )
          end

          it_behaves_like 'open telemetry trackable' do
            let(:expected_spans_name) { ['DummyClass'] }
            let(:expected_spans_kind) { [:client] }
            let(:expected_spans_amount) { 1 }
            let(:extra_attribute_keys) { { 'DummyClass' => { 'test' => 'test' } } }
          end
        end

        context 'when span_name is provided' do
          subject { dummy_instance.dummy_method_with_sql(data) }

          before do
            DummyClass.otl_trackable :dummy_method_with_sql, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(
              span_name: 'DummyMethod4',
              span_kind: :client,
              span_attributes: { 'test' => 'test' },
              links_extractor: ->(data, **) { data['otl_context'] },
              track_sql: true
            )
          end

          let(:data) { { 'otl_context' => { 'root_context' => { 'traceparent' => '00-12345678901234567890123456789012-1234567890123456-01' } } } }

          it_behaves_like 'open telemetry trackable' do
            let(:expected_spans_name) { ['DummyMethod4', 'SQL TestUser Load'] }
            let(:expected_spans_kind) { %i[client internal] }
            let(:expected_spans_amount) { 2 }
            let(:extra_attribute_keys) {  { 'DummyMethod4' => { 'test' => 'test', 'track_sql' => true } } }
          end
          it 'creates a proper links' do
            subject

            aggregate_failures do
              links = in_memory_exporter.finished_spans.last.links

              expect(links).to be_present
              expect(links.last.span_context.trace_id.unpack1('H*')).to eq('12345678901234567890123456789012')
              expect(links.last.span_context.span_id.unpack1('H*')).to eq('1234567890123456')
            end
          end
        end
      end
    end
  end

  describe '.otl_tracer' do
    subject { dummy_class.otl_tracer }

    before do
      Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
    end

    it 'returns a configured tracer' do
      expect(subject).to eq(Yes::Core.configuration.otl_tracer)
    end
  end

  describe '.current_span' do
    subject { dummy_class.current_span }

    it_behaves_like 'no open telemetry tracing'

    context 'when a tracer is configured' do
      before do
        Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
      end

      it 'returns the current span' do
        expect(subject).to be_a(OpenTelemetry::Trace::Span)
      end
    end
  end

  describe '.current_context' do
    subject { dummy_class.current_context }

    it_behaves_like 'no open telemetry tracing'

    context 'when a tracer is configured' do
      before do
        Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
      end

      it 'returns the current context' do
        expect(subject).to be_a(OpenTelemetry::Context)
      end
    end
  end

  describe '.with_otl_span' do
    subject { dummy_class.with_otl_span('MySpan') { 'test' } }

    it_behaves_like 'no open telemetry tracing' do
      let(:returned_result) { 'test' }
    end

    context 'when a tracer is configured' do
      before do
        Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
      end

      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_name) { ['MySpan'] }
        let(:expected_spans_kind) { [:internal] }
        let(:expected_spans_amount) { 1 }
        let(:default_attribute_keys) { {} }
      end
      it 'returns the result of the block' do
        expect(subject).to eq('test')
      end
    end
  end

  describe '.propagate_context' do
    subject do
      OpenTelemetry.tracer_provider.tracer('SpecTracer').in_span('test') do
        dummy_class.propagate_context(carrier, service_name:)
      end
    end

    let(:carrier) { {} }
    let(:service_name) { true }

    before do
      Yes::Core.configuration.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
    end

    it 'returns carrier with propagated context' do
      expect(subject[:service]).to eq(Rails.application.class.module_parent.name)
      expect(subject[:traceparent]).to be_present
    end

    context 'when service name is set to false' do
      let(:service_name) { false }

      it 'does not propagate service name' do
        expect(subject[:service]).to be_nil
      end
    end
  end

  describe '.extract_current_context' do
    subject { dummy_class.extract_current_context(carrier) }

    let(:carrier) { { 'traceparent' => '00-01234567890123456789012345678901-0123456789012345-01' } }

    it 'returns extracted context from carrier' do
      aggregate_failures do
        expect(subject).to be_a(OpenTelemetry::Context)
        context = subject.instance_variable_get(:@entries).values.first.context
        expect(context.trace_id.unpack1('H*')).to eq('01234567890123456789012345678901')
        expect(context.span_id.unpack1('H*')).to eq('0123456789012345')
      end
    end

    context 'when carrier does not have traceparent' do
      let(:carrier) { {} }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
