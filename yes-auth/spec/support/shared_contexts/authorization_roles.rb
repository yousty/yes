# frozen_string_literal: true

RSpec.shared_context :authorization_roles do
  let!(:super_admin_role) { FactoryBot.create(:auth_principals_role, :super_admin) }

  let!(:company_admin_role) { FactoryBot.create(:auth_principals_role, :company_admin) }
  let!(:company_recruiter_role) { FactoryBot.create(:auth_principals_role, :company_recruiter) }
  let!(:company_editor_role) { FactoryBot.create(:auth_principals_role, :company_editor) }
end
