# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::Cerbos::ReadResourceAccess::PrincipalData do
  include_context :authorization_roles

  subject { described_class.call(auth_data) }

  let(:auth_data) { { identity_id: } }

  let(:company1) { FactoryBot.create(:company) }
  let(:company2) { FactoryBot.create(:company) }

  let(:apprenticeship1) { FactoryBot.create(:apprenticeship) }
  let(:apprenticeship2) { FactoryBot.create(:apprenticeship) }

  let(:location1) { FactoryBot.create(:location) }

  let(:company_admin) { company_admin_role }
  let(:company_recruiter) { company_recruiter_role }

  let(:identity_id) { user1.identity_id }

  let(:user1) do
    FactoryBot.create(
      :auth_principals_user,
      identity_id: SecureRandom.uuid,
      role_ids: [company_admin.id, company_recruiter.id],
      auth_attributes: user1_auth_attributes
    )
  end

  let(:user1_auth_attributes) do
    {
      user_auth_attr1: 'auth_attr1',
      user_auth_attr2: 'auth_attr2',
      user_auth_some_ids: [1, 2, 3]
    }
  end

  let(:user2) do
    FactoryBot.create(
      :auth_principals_user,
      identity_id: SecureRandom.uuid,
      role_ids: [company_recruiter.id],
      auth_attributes: { auth_attr1: 'xyz' }
    )
  end

  let!(:company1_admin_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user1.id,
      resource_id: company1.id,
      role_id: company_admin.id,
      service: 'company_manager',
      resource_type: 'company',
      auth_attributes: { read_attr1a: 'read_attr1a', read_attr2a: 'read_attr2a' }
    )
  end

  let!(:company1_recruiter_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user1.id,
      resource_id: company1.id,
      role_id: company_recruiter.id,
      service: 'company_manager',
      resource_type: 'company',
      auth_attributes: { read_attr: 'read_attrxyz' }
    )
  end

  let!(:company2_admin_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user1.id,
      resource_id: company2.id,
      role_id: company_admin.id,
      service: 'company_manager',
      resource_type: 'company'
    )
  end

  let!(:location1_company_admin_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user1.id,
      resource_id: location1.id,
      role_id: company_admin.id,
      service: 'company_manager',
      resource_type: 'location',
      auth_attributes: { address: 'address1' }
    )
  end

  let!(:apprenticeship1_company_recruiter_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user1.id,
      resource_id: apprenticeship1.id,
      role_id: company_recruiter.id,
      service: 'apprenticeship_presentation',
      scope: 'statistics',
      resource_type: 'apprenticeship',
      auth_attributes: { apprenticeship_id: '111' }
    )
  end

  let!(:apprenticeship2_company_recruiter_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user1.id,
      resource_id: apprenticeship2.id,
      role_id: company_recruiter.id,
      service: 'apprenticeship_presentation',
      scope: 'statistics',
      resource_type: 'apprenticeship',
      auth_attributes: { apprenticeship_id: '222' }
    )
  end

  let!(:another_principal_apprenticeship1_company_recruiter_read_resource_access) do
    FactoryBot.create(
      :auth_principals_read_resource_access,
      principal_id: user2.id,
      resource_id: apprenticeship1.id,
      role_id: company_recruiter.id,
      service: 'apprenticeship_presentation',
      scope: 'statistics',
      resource_type: 'apprenticeship',
      auth_attributes: { apprenticeship_id: '222' }
    )
  end

  describe '.call' do
    it 'returns the expected principal data' do
      expect(subject).to match(
        {
          id: user1.identity_id,
          roles: user1.read_resource_access_authorization_roles,
          attributes: {
            user_auth_attr1: 'auth_attr1',
            user_auth_attr2: 'auth_attr2',
            user_auth_some_ids: [1, 2, 3],
            read_resource_access: {
              company_manager: {
                root: {
                  company: {
                    company_admin: {
                      company1.id => {
                        read_attr1a: 'read_attr1a',
                        read_attr2a: 'read_attr2a'
                      },
                      company2.id => {}
                    },
                    company_recruiter: {
                      company1.id => {
                        read_attr: 'read_attrxyz'
                      }
                    }
                  },
                  location: {
                    company_admin: {
                      location1.id => {
                        address: 'address1'
                      }
                    }
                  }
                }
              },
              apprenticeship_presentation: {
                statistics: {
                  apprenticeship: {
                    company_recruiter: {
                      apprenticeship1.id => {
                        apprenticeship_id: '111'
                      },
                      apprenticeship2.id => {
                        apprenticeship_id: '222'
                      }
                    }
                  }
                }
              }
            }
          }
        }.with_indifferent_access
      )
    end

    context 'when identity not existing' do
      let(:identity_id) { SecureRandom.uuid }

      it 'returns an empty hash' do
        expect(subject).to eq({})
      end
    end

    context 'when identity has no read resource access yet' do
      let(:read_resource_accesses) { [] }

      let(:user_without_resource_access) do
        FactoryBot.create(
          :auth_principals_user,
          identity_id: SecureRandom.uuid,
          role_ids: [company_recruiter.id],
          auth_attributes: { auth_attr1: 'xyz' }
        )
      end

      let(:identity_id) { user_without_resource_access.identity_id }

      it 'returns the expected principal attributes' do
        expect(subject).to eq(
          {
            id: user_without_resource_access.identity_id,
            roles: user_without_resource_access.read_resource_access_authorization_roles,
            attributes: {
              **user_without_resource_access.auth_attributes,
              read_resource_access: {}
            }
          }.with_indifferent_access
        )
      end
    end
  end
end
