# frozen_string_literal: true

RSpec.shared_context :authorization_roles do
  let(:super_admin_role) { OpenStruct.new(id: SecureRandom.uuid, name: 'super_admin') }
  let(:company_admin_role) { OpenStruct.new(id: SecureRandom.uuid, name: 'company_admin') }
  let(:company_recruiter_role) { OpenStruct.new(id: SecureRandom.uuid, name: 'company_recruiter') }
  let(:company_editor_role) { OpenStruct.new(id: SecureRandom.uuid, name: 'company_editor') }
end
