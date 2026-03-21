# frozen_string_literal: true

require_relative 'lib/yes/core/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-core'
  spec.version = Yes::Core::VERSION
  spec.authors = ['Nico Ritsche']
  spec.email = ['nico.ritsche@gmail.com']

  spec.summary = 'Core functionality for the Yes event sourcing framework'
  spec.description = 'Provides core functionality for the Yes event sourcing framework'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main/yes-core"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/yes-core/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['{lib}/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'cerbos', '~> 0.8'
  spec.add_dependency 'dry-inflector'
  spec.add_dependency 'dry-schema'
  spec.add_dependency 'dry-struct'
  spec.add_dependency 'dry-types'
  spec.add_dependency 'has_scope'
  spec.add_dependency 'jsonapi-serializer'
  spec.add_dependency 'pg_eventstore'
  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'zeitwerk'
end
