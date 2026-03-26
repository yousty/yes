# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Lint/EmptyClass
module Yes
  module Auth
    module ReadModels
      module Principals
        module Role
          class Builder; end
        end

        module User
          class Builder; end
        end

        module WriteResourceAccess
          class Builder; end
        end

        module ReadResourceAccess
          class Builder; end
        end
      end
    end
  end
end
# rubocop:enable Lint/EmptyClass

RSpec.describe Yes::Auth::Subscriptions do
  describe '.call' do
    subject(:call) { described_class.call(subscriptions) }

    let(:subscriptions) { instance_double('Subscriptions') }

    before do
      allow(subscriptions).to receive(:subscribe_to_all)
    end

    it 'subscribes the role builder' do
      call

      expect(subscriptions).to have_received(:subscribe_to_all).with(
        an_instance_of(Yes::Auth::ReadModels::Principals::Role::Builder),
        { event_types: ['Authorization::RoleNameChanged'] }
      )
    end

    it 'subscribes the user builder' do
      call

      expect(subscriptions).to have_received(:subscribe_to_all).with(
        an_instance_of(Yes::Auth::ReadModels::Principals::User::Builder),
        { event_types: [
          'Authorization::PrincipalRoleAdded',
          'Authorization::PrincipalRoleRemoved',
          'Authorization::PrincipalAttributeChanged',
          'Authorization::PrincipalIdentityAssigned',
          'Authorization::PrincipalRemoved'
        ] }
      )
    end

    it 'subscribes the write resource access builder' do
      call

      expect(subscriptions).to have_received(:subscribe_to_all).with(
        an_instance_of(Yes::Auth::ReadModels::Principals::WriteResourceAccess::Builder),
        { event_types: [
          'Authorization::WriteResourceAccessAttributeChanged',
          'Authorization::WriteResourceAccessContextChanged',
          'Authorization::WriteResourceAccessPrincipalAssigned',
          'Authorization::WriteResourceAccessRemoved',
          'Authorization::WriteResourceAccessResourceAssigned',
          'Authorization::WriteResourceAccessResourceTypeChanged',
          'Authorization::WriteResourceAccessRoleChanged'
        ] }
      )
    end

    it 'subscribes the read resource access builder' do
      call

      expect(subscriptions).to have_received(:subscribe_to_all).with(
        an_instance_of(Yes::Auth::ReadModels::Principals::ReadResourceAccess::Builder),
        { event_types: [
          'Authorization::ReadResourceAccessPrincipalAssigned',
          'Authorization::ReadResourceAccessResourceTypeChanged',
          'Authorization::ReadResourceAccessRemoved',
          'Authorization::ReadResourceAccessResourceAssigned',
          'Authorization::ReadResourceAccessRoleChanged',
          'Authorization::ReadResourceAccessScopeChanged',
          'Authorization::ReadResourceAccessServiceChanged'
        ] }
      )
    end
  end
end
