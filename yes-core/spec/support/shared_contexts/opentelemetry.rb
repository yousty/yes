# frozen_string_literal: true

RSpec.shared_context :opentelemetry do
  let(:in_memory_exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:finished_spans) { in_memory_exporter.finished_spans }

  before do
    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(in_memory_exporter))

      c.service_name = 'SpecService'
      c.service_version = ENV.fetch('APP_VERSION', '1.0.0')
    end
  end
end
