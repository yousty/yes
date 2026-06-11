# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::ReadModels::Principals::RestoreReplay do
  subject(:replay) do
    described_class.new(
      builder: Yes::Auth::ReadModels::Principals::WriteResourceAccess::Builder.new,
      stream_name: 'WriteResourceAccess'
    ).call(read_model, eventstore:)
  end

  let(:access_id) { '0b9efc06-2bcd-4cbe-bd02-d2eb5e0d1adc' }
  let(:read_model) { Yes::Auth::Principals::WriteResourceAccess.create!(id: access_id) }
  let(:eventstore) { instance_double(PgEventstore::Client, read_paginated: [events]) }

  let(:events) do
    [
      event('Authorization::WriteResourceAccessResourceAssigned', 'resource_id' => 'resource-1'),
      event('Authorization::WriteResourceAccessPrincipalAssigned', 'principal_id' => 'principal-1'),
      event('Authorization::WriteResourceAccessContextChanged', 'context' => 'company_management'),
      event('Authorization::WriteResourceAccessResourceTypeChanged', 'resource_type' => 'apprenticeship'),
      event('Authorization::WriteResourceAccessRoleChanged', 'role_id' => 'role-1'),
      event('Authorization::WriteResourceAccessRemoved'),
      event('Authorization::WriteResourceAccessRestored')
    ]
  end

  def event(type, data = {})
    PgEventstore::Event.new(type:, data: data.merge('write_resource_access_id' => access_id))
  end

  it 'rebuilds the row from the per-field events' do
    replay

    aggregate_failures do
      expect(read_model.reload).to have_attributes(
        resource_id: 'resource-1',
        principal_id: 'principal-1',
        context: 'company_management',
        resource_type: 'apprenticeship',
        role_id: 'role-1'
      )
    end
  end

  it 'skips lifecycle events so the row survives the replay' do
    replay

    expect(Yes::Auth::Principals::WriteResourceAccess.exists?(access_id)).to be true
  end

  it 'reads the aggregate stream of the read model' do
    replay

    expect(eventstore).to have_received(:read_paginated).with(
      having_attributes(context: 'Authorization', stream_name: 'WriteResourceAccess', stream_id: access_id),
      options: { resolve_link_tos: true }
    )
  end
end
