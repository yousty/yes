# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::Principals::User do
  describe 'class configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('auth_principals_users')
    end
  end

  describe 'constants' do
    it 'defines NO_AUTHORIZATION_ROLES_YET' do
      expect(described_class::NO_AUTHORIZATION_ROLES_YET).to eq(['no-roles-yet'])
    end

    it 'freezes NO_AUTHORIZATION_ROLES_YET' do
      expect(described_class::NO_AUTHORIZATION_ROLES_YET).to be_frozen
    end
  end

  describe 'associations' do
    it 'has and belongs to many roles' do
      association = described_class.reflect_on_association(:roles)

      aggregate_failures do
        expect(association.macro).to eq(:has_and_belongs_to_many)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::Role')
        expect(association.options[:foreign_key]).to eq(:auth_principals_user_id)
        expect(association.options[:association_foreign_key]).to eq(:auth_principals_role_id)
      end
    end

    it 'has many write_resource_accesses' do
      association = described_class.reflect_on_association(:write_resource_accesses)

      aggregate_failures do
        expect(association.macro).to eq(:has_many)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::WriteResourceAccess')
        expect(association.options[:foreign_key]).to eq(:principal_id)
      end
    end

    it 'has many read_resource_accesses' do
      association = described_class.reflect_on_association(:read_resource_accesses)

      aggregate_failures do
        expect(association.macro).to eq(:has_many)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::ReadResourceAccess')
        expect(association.options[:foreign_key]).to eq(:principal_id)
      end
    end
  end

  describe '#read_resource_access_authorization_roles' do
    subject(:authorization_roles) { user.read_resource_access_authorization_roles }

    let(:user) { described_class.create!(id: 'user-uuid', identity_id: 'identity-uuid') }
    let(:direct_role) { Yes::Auth::Principals::Role.create!(id: 'direct-role-uuid', name: 'direct_role') }
    let(:read_role) { Yes::Auth::Principals::Role.create!(id: 'read-role-uuid', name: 'read_role') }

    before do
      user.roles << direct_role

      Yes::Auth::Principals::ReadResourceAccess.create!(
        id: 'read-access-uuid', principal_id: user.id, role_id: read_role.id,
        service: 'svc', scope: 'tenant', resource_type: 'Company', resource_id: 'company-uuid'
      )
    end

    it 'returns combined read resource access roles and direct roles' do
      expect(authorization_roles).to contain_exactly('read_role', 'direct_role')
    end
  end

  describe '#write_resource_access_authorization_roles' do
    subject(:authorization_roles) { user.write_resource_access_authorization_roles }

    let(:user) { described_class.create!(id: 'user-uuid', identity_id: 'identity-uuid') }
    let(:direct_role) { Yes::Auth::Principals::Role.create!(id: 'direct-role-uuid', name: 'direct_role') }
    let(:write_role) { Yes::Auth::Principals::Role.create!(id: 'write-role-uuid', name: 'write_role') }

    before do
      user.roles << direct_role

      Yes::Auth::Principals::WriteResourceAccess.create!(
        id: 'write-access-uuid', principal_id: user.id, role_id: write_role.id,
        context: 'hiring', resource_type: 'Company', resource_id: 'company-uuid'
      )
    end

    it 'returns combined write resource access roles and direct roles' do
      expect(authorization_roles).to contain_exactly('write_role', 'direct_role')
    end
  end

  describe '#super_admin?' do
    subject(:super_admin) { user.super_admin? }

    let(:user) { described_class.create!(id: 'user-uuid', identity_id: 'identity-uuid') }

    context 'when super admin role does not exist' do
      it { is_expected.to be false }
    end

    context 'when user has the super admin role' do
      let(:admin_role) { Yes::Auth::Principals::Role.create!(id: 'admin-role-uuid', name: 'admin') }

      before { user.roles << admin_role }

      it { is_expected.to be true }
    end

    context 'when user does not have the super admin role' do
      before do
        Yes::Auth::Principals::Role.create!(id: 'admin-role-uuid', name: 'admin')
        other_role = Yes::Auth::Principals::Role.create!(id: 'other-role-uuid', name: 'viewer')
        user.roles << other_role
      end

      it { is_expected.to be false }
    end
  end
end
