# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::ReadModels::Principals::WriteResourceAccess::OnWriteResourceAccessRestored do
  describe '#call' do
    subject(:call) { described_class.new(read_model).call(event) }

    let(:read_model) { Yes::Auth::Principals::WriteResourceAccess.create!(id: 'access-1') }
    let(:event) { PgEventstore::Event.new(type: 'Authorization::WriteResourceAccessRestored') }
    let(:replay) { instance_double(Yes::Auth::ReadModels::Principals::RestoreReplay, call: nil) }

    before do
      allow(Yes::Auth::ReadModels::Principals::RestoreReplay).to receive(:new).and_return(replay)
    end

    it 'replays the aggregate stream into the read model' do
      call

      aggregate_failures do
        expect(Yes::Auth::ReadModels::Principals::RestoreReplay).to have_received(:new).with(
          builder: an_instance_of(Yes::Auth::ReadModels::Principals::WriteResourceAccess::Builder),
          stream_name: 'WriteResourceAccess'
        )
        expect(replay).to have_received(:call).with(read_model)
      end
    end
  end
end
