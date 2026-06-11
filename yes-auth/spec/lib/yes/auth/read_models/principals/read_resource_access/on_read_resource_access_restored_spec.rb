# frozen_string_literal: true

require 'spec_helper'
require 'active_job'
require 'active_job/railtie'
require 'yes/core'
require 'yes/auth/read_models/principals/restore_replay'
require 'yes/auth/read_models/principals/read_resource_access/builder'
require 'yes/auth/read_models/principals/read_resource_access/on_read_resource_access_restored'

RSpec.describe Yes::Auth::ReadModels::Principals::ReadResourceAccess::OnReadResourceAccessRestored do
  describe '#call' do
    subject(:call) { described_class.new(read_model).call(event) }

    let(:read_model) { Yes::Auth::Principals::ReadResourceAccess.create!(id: 'access-1') }
    let(:event) { PgEventstore::Event.new(type: 'Authorization::ReadResourceAccessRestored') }
    let(:replay) { instance_double(Yes::Auth::ReadModels::Principals::RestoreReplay, call: nil) }

    before do
      allow(Yes::Auth::ReadModels::Principals::RestoreReplay).to receive(:new).and_return(replay)
    end

    it 'replays the aggregate stream into the read model' do
      call

      aggregate_failures do
        expect(Yes::Auth::ReadModels::Principals::RestoreReplay).to have_received(:new).with(
          builder: an_instance_of(Yes::Auth::ReadModels::Principals::ReadResourceAccess::Builder),
          stream_name: 'ReadResourceAccess'
        )
        expect(replay).to have_received(:call).with(read_model)
      end
    end
  end
end
