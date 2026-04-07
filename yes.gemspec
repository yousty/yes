# frozen_string_literal: true

require_relative 'lib/yes/version'

Gem::Specification.new do |spec|
  spec.name = 'yes'
  spec.version = Yes::VERSION
  spec.authors = ['Nico Ritsche']
  spec.email = ['nico.ritsche@yousty.ch']

  spec.summary = 'Yes event sourcing framework'
  spec.description = 'Event sourcing framework for Ruby on Rails applications'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['{lib}/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'yes-command-api', Yes::VERSION
  spec.add_dependency 'yes-core', Yes::VERSION
  spec.add_dependency 'yes-read-api', Yes::VERSION
end
