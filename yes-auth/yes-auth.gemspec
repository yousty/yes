# frozen_string_literal: true

require_relative 'lib/yes/auth/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-auth'
  spec.version = Yes::Auth::VERSION
  spec.authors = ['Nico Ritsche']
  spec.email = ['nico.ritsche@gmail.com']

  spec.summary = 'Authorization principals for the Yes event sourcing framework'
  spec.description = 'Provides authorization principal models (User, Role, ResourceAccess) and Cerbos integration for the Yes framework'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main/yes-auth"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/yes-auth/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['{lib}/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'yes-core', '~> 1.0'
end
