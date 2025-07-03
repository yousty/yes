# frozen_string_literal: true

require_relative 'lib/yes/version'

Gem::Specification.new do |spec|
  spec.name = 'yes'
  spec.version = Yes::VERSION
  spec.authors = ['ncri']
  spec.email = ['nico.ritsche@gmail.com']

  spec.summary = 'Yes event sourcing framework'
  spec.description = 'Event sourcing framework for Ruby on Rails applications'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = "https://#{ENV.fetch('GEM_FURY_PUSH_TOKEN', nil)}@push.fury.io/yousty-ag/"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir['{lib,sig}/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'yes-command-api' # , Yes::VERSION
  spec.add_dependency 'yes-core' # , Yes::VERSION
  spec.add_dependency 'yes-read-api' # , Yes::VERSION

  spec.metadata['rubygems_mfa_required'] = 'true'
end
