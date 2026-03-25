# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::Principals::ReadResourceAccess do
  describe 'class configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('auth_principals_read_resource_accesses')
    end
  end

  describe 'associations' do
    it 'belongs to role optionally' do
      association = described_class.reflect_on_association(:role)

      aggregate_failures do
        expect(association.macro).to eq(:belongs_to)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::Role')
        expect(association.options[:optional]).to be true
      end
    end
  end

  describe '#authorization_complete?' do
    subject(:authorization_complete) { access.authorization_complete? }

    let(:role) { Yes::Auth::Principals::Role.create!(id: 'role-uuid', name: 'viewer') }

    context 'when all required fields are present' do
      let(:access) do
        described_class.create!(
          id: 'access-uuid', principal_id: 'user-uuid', role_id: role.id,
          service: 'my-service', scope: 'tenant', resource_type: 'Company', resource_id: 'resource-uuid'
        )
      end

      it { is_expected.to be true }
    end

    context 'when service is missing' do
      let(:access) do
        described_class.create!(
          id: 'access-uuid', principal_id: 'user-uuid', role_id: role.id,
          service: nil, scope: 'tenant', resource_type: 'Company', resource_id: 'resource-uuid'
        )
      end

      it { is_expected.to be false }
    end

    context 'when scope is missing' do
      let(:access) do
        described_class.create!(
          id: 'access-uuid', principal_id: 'user-uuid', role_id: role.id,
          service: 'my-service', scope: nil, resource_type: 'Company', resource_id: 'resource-uuid'
        )
      end

      it { is_expected.to be false }
    end

    context 'when resource_type is missing' do
      let(:access) do
        described_class.create!(
          id: 'access-uuid', principal_id: 'user-uuid', role_id: role.id,
          service: 'my-service', scope: 'tenant', resource_type: nil, resource_id: 'resource-uuid'
        )
      end

      it { is_expected.to be false }
    end

    context 'when role is missing' do
      let(:access) do
        described_class.create!(
          id: 'access-uuid', principal_id: 'user-uuid', role_id: nil,
          service: 'my-service', scope: 'tenant', resource_type: 'Company', resource_id: 'resource-uuid'
        )
      end

      it { is_expected.to be false }
    end

    context 'when resource_id is missing' do
      let(:access) do
        described_class.create!(
          id: 'access-uuid', principal_id: 'user-uuid', role_id: role.id,
          service: 'my-service', scope: 'tenant', resource_type: 'Company', resource_id: nil
        )
      end

      it { is_expected.to be false }
    end
  end
end
