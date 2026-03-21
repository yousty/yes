# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::ReadModelAuthorizer do
  describe '.call' do
    subject { described_class.call(record, auth_data) }

    let(:auth_data) { nil }
    let(:record) { nil }

    it 'raises NotAuthorized error by default' do
      expect { subject }.to(
        raise_error(Yes::Core::Authorization::ReadModelAuthorizer::NotAuthorized)
      )
    end
  end
end
