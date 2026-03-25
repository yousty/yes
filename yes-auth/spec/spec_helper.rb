# frozen_string_literal: true

require 'active_record'
require 'active_support/core_ext/hash/indifferent_access'
require 'factory_bot'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :auth_principals_users, id: :string do |t|
    t.string :identity_id
    t.json :auth_attributes
  end

  create_table :auth_principals_roles, id: :string do |t|
    t.string :name
  end

  create_table :auth_principals_roles_users, id: false do |t|
    t.string :auth_principals_user_id
    t.string :auth_principals_role_id
  end

  create_table :auth_principals_read_resource_accesses, id: :string do |t|
    t.string :principal_id
    t.string :role_id
    t.string :service
    t.string :scope
    t.string :resource_type
    t.string :resource_id
    t.json :auth_attributes
  end

  create_table :auth_principals_write_resource_accesses, id: :string do |t|
    t.string :principal_id
    t.string :role_id
    t.string :context
    t.string :resource_type
    t.string :resource_id
    t.json :auth_attributes
  end

  create_table :companies, id: :string

  create_table :apprenticeships, id: :string

  create_table :locations, id: :string
end

require 'yes/auth/principals/user'
require 'yes/auth/principals/role'
require 'yes/auth/principals/read_resource_access'
require 'yes/auth/principals/write_resource_access'
require 'yes/auth/cerbos/read_resource_access/principal_attributes'
require 'yes/auth/cerbos/read_resource_access/principal_data'
require 'yes/auth/cerbos/write_resource_access/principal_attributes'
require 'yes/auth/cerbos/write_resource_access/principal_data'
require 'yes/auth/subscriptions'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
