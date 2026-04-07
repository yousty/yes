# frozen_string_literal: true

require_relative 'lib/yes/command/api/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-command-api'
  spec.version = Yes::Command::Api::VERSION
  spec.authors = ['Nico Ritsche']
  spec.email = ['nico.ritsche@yousty.ch']

  spec.summary = 'Command API for the Yes event sourcing framework'
  spec.description = 'Command API for the Yes event sourcing framework'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main/yes-command-api"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/yes-command-api/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'message_bus', '~> 4.0'
  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'yes-core'
end
