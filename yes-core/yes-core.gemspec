# frozen_string_literal: true

require_relative 'lib/yes/core/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-core'
  spec.version = Yes::Core::VERSION
  spec.authors = ['ncri']
  spec.email = ['nico.ritsche@gmail.com']

  spec.summary = 'Core functionality for the Yes event sourcing framework'
  spec.description = 'Provides core functionality for the Yes event sourcing framework'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir['{lib,sig}/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'pg_eventstore'
  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'yousty-api', '~> 1.4'
  spec.add_dependency 'zeitwerk'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
