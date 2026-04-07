# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::Cerbos::ReadResourceAccess::PrincipalAttributes do
  include_context :authorization_roles

  subject { described_class.call(principal:, read_resource_accesses:) }

  let(:principal) { user1 }
  let(:read_resource_accesses) do
    [
      company1_admin_read_resource_access,
      company1_recruiter_read_resource_access,
      company2_admin_read_resource_access,
      location1_company_admin_read_resource_access,
      apprenticeship1_company_recruiter_read_resource_access,
      apprenticeship2_company_recruiter_read_resource_access
    ]
  end

  let(:company1) { FactoryBot.create(:company) }
  let(:company2) { FactoryBot.create(:company) }

  let(:apprenticeship1) { FactoryBot.create(:apprenticeship) }
  let(:apprenticeship2) { FactoryBot.create(:apprenticeship) }

  let(:location1) { FactoryBot.create(:location) }

  let(:company_admin) { company_admin_role }
  let(:company_recruiter) { company_recruiter_role }

  let(:identity_id1) { SecureRandom.uuid }

  let(:user1) do
    FactoryBot.create(
      :auth_principals_user,
      identity_id: identity_id1,
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

  describe '.call' do
    it 'returns the expected principal attributes' do
      expect(subject).to match(
        {
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
        }.with_indifferent_access
      )
    end

    context 'when principal not provided' do
      let(:principal) { nil }

      it 'returns an empty hash' do
        expect(subject).to eq({})
      end
    end

    context 'when read_resource_accesses not provided' do
      let(:read_resource_accesses) { [] }

      it 'returns the expected principal attributes' do
        expect(subject).to eq(
          {
            **user1_auth_attributes,
            read_resource_access: {}
          }.with_indifferent_access
        )
      end
    end

    context 'when principal auth_attributes not present' do
      let(:user1) do
        FactoryBot.create(
          :auth_principals_user,
          identity_id: identity_id1,
          role_ids: [company_admin.id, company_recruiter.id]
        )
      end
      let(:read_resource_accesses) { [] }

      it 'returns the expected principal attributes' do
        expect(subject).to eq({ read_resource_access: {} }.with_indifferent_access)
      end
    end

    shared_examples 'principal attributes without incomplete access' do
      it 'returns the expected principal attributes, without incomplete access attributes' do
        expect(subject).to match(
          {
            **user1_auth_attributes,
            read_resource_access: {
              company_manager: {
                root: {
                  company: {
                    company_admin: {
                      company1.id => {
                        read_attr1a: 'read_attr1a',
                        read_attr2a: 'read_attr2a'
                      }
                    }
                  }
                }
              }
            }
          }.with_indifferent_access
        )
      end
    end

    context 'when some resource access is incomplete' do
      let(:company) { FactoryBot.create(:company) }

      let(:read_resource_accesses) do
        [
          company1_admin_read_resource_access,
          incomplete_read_resource_access
        ]
      end

      context 'when context is missing' do
        let!(:incomplete_read_resource_access) do
          FactoryBot.create(
            :auth_principals_read_resource_access,
            principal_id: user1.id,
            service: nil,
            role_id: company_admin.id,
            resource_type: 'company',
            resource_id: company.id,
            auth_attributes: { attr1: 'val1' }
          )
        end

        it_behaves_like 'principal attributes without incomplete access'
      end

      context 'when resource_type is missing' do
        let!(:incomplete_read_resource_access) do
          FactoryBot.create(
            :auth_principals_read_resource_access,
            principal_id: user1.id,
            service: 'company_manager',
            role_id: company_admin.id,
            resource_type: nil,
            resource_id: company.id,
            auth_attributes: { attr1: 'val1' }
          )
        end

        it_behaves_like 'principal attributes without incomplete access'
      end

      context 'when role is missing' do
        let!(:incomplete_read_resource_access) do
          FactoryBot.create(
            :auth_principals_read_resource_access,
            principal_id: user1.id,
            service: 'company_manager',
            role_id: nil,
            resource_type: 'company',
            resource_id: company.id,
            auth_attributes: { attr1: 'val1' }
          )
        end

        it_behaves_like 'principal attributes without incomplete access'
      end

      context 'when resource_id is missing' do
        let!(:incomplete_read_resource_access) do
          FactoryBot.create(
            :auth_principals_read_resource_access,
            principal_id: user1.id,
            service: 'company_manager',
            role_id: company_admin.id,
            resource_type: 'company',
            resource_id: nil,
            auth_attributes: { attr1: 'val1' }
          )
        end

        it_behaves_like 'principal attributes without incomplete access'
      end

      context 'when auth_attributes is missing' do
        let!(:incomplete_read_resource_access) do
          FactoryBot.create(
            :auth_principals_read_resource_access,
            principal_id: user1.id,
            service: 'company_manager',
            role_id: company_admin.id,
            resource_type: 'company',
            resource_id: company.id
          )
        end

        it 'returns the expected principal attributes' do
          expect(subject).to match(
            {
              **user1_auth_attributes,
              read_resource_access: {
                company_manager: {
                  root: {
                    company: {
                      company_admin: {
                        company1.id => {
                          read_attr1a: 'read_attr1a',
                          read_attr2a: 'read_attr2a'
                        },
                        company.id => {}
                      }
                    }
                  }
                }
              }
            }.with_indifferent_access
          )
        end
      end
    end
  end
end
