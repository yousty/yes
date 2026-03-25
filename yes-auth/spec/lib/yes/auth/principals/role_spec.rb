# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::Principals::Role do
  describe 'class configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('auth_principals_roles')
    end
  end

  describe 'constants' do
    it 'defines SUPER_ADMIN_ROLE_NAME' do
      expect(described_class::SUPER_ADMIN_ROLE_NAME).to eq('admin')
    end
  end

  describe 'associations' do
    it 'has and belongs to many users' do
      association = described_class.reflect_on_association(:users)

      aggregate_failures do
        expect(association.macro).to eq(:has_and_belongs_to_many)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::User')
        expect(association.options[:foreign_key]).to eq(:auth_principals_role_id)
        expect(association.options[:association_foreign_key]).to eq(:auth_principals_user_id)
      end
    end

    it 'has many read_resource_accesses' do
      association = described_class.reflect_on_association(:read_resource_accesses)

      aggregate_failures do
        expect(association.macro).to eq(:has_many)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::ReadResourceAccess')
      end
    end

    it 'has many write_resource_accesses' do
      association = described_class.reflect_on_association(:write_resource_accesses)

      aggregate_failures do
        expect(association.macro).to eq(:has_many)
        expect(association.options[:class_name]).to eq('Yes::Auth::Principals::WriteResourceAccess')
      end
    end
  end

  describe '#resource_authorization_name' do
    subject(:resource_authorization_name) { role.resource_authorization_name }

    context 'when name contains colons' do
      let(:role) { described_class.create!(id: 'role-uuid', name: 'company:manager') }

      it { is_expected.to eq('company_manager') }
    end

    context 'when name has no colons' do
      let(:role) { described_class.create!(id: 'role-uuid', name: 'admin') }

      it { is_expected.to eq('admin') }
    end

    context 'when name is nil' do
      let(:role) { described_class.create!(id: 'role-uuid', name: nil) }

      it { is_expected.to be_nil }
    end
  end

  describe '.super_admin_role' do
    subject(:super_admin_role) { described_class.super_admin_role }

    context 'when admin role exists' do
      before { described_class.create!(id: 'admin-role-uuid', name: 'admin') }

      it 'finds the admin role' do
        expect(super_admin_role).to be_present
        expect(super_admin_role.name).to eq('admin')
      end
    end

    context 'when admin role does not exist' do
      it { is_expected.to be_nil }
    end
  end
end
