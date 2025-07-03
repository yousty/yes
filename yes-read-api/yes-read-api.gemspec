# frozen_string_literal: true

require_relative 'lib/yes/read/api/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-read-api'
  spec.version = Yes::Read::Api::VERSION
  spec.authors = ['Arek Swidrak']
  spec.email = ['arek@useo.pl']

  spec.summary = 'Yes Read Api'
  spec.description = 'Read API for the Yousty eventsourced microservice architecture.'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1')

  spec.metadata['allowed_push_host'] =
    "https://#{ENV.fetch('GEM_FURY_PUSH_TOKEN', nil)}@push.fury.io/yousty-ag/"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/yousty/yes/tree/main/yes-read-api'
  spec.metadata['changelog_uri'] = 'https://github.com/yousty/yes/blob/main/yes-read-api/CHANGELOG.md'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'api-pagination', '~> 5.0'
  spec.add_dependency 'jwt_token_auth_client_rails', '~> 3.3'
  spec.add_dependency 'pagy', '~> 6.0'
  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'yousty-eventsourcing', '>= 7'

  spec.add_development_dependency 'dotenv-rails', '~> 2.8'
  spec.add_development_dependency 'factory_bot', '~> 6.0'
  spec.add_development_dependency 'pg', '~> 1.5'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails', '~> 6.0.2'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'simplecov-formatter-badge', '~> 0.1'
  spec.add_development_dependency 'yousty_dev_tools', '~> 0.1'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
