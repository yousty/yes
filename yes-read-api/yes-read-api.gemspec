# frozen_string_literal: true

require_relative 'lib/yes/read/api/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-read-api'
  spec.version = Yes::Read::Api::VERSION
  spec.authors = ['Nico Ritsche']
  spec.email = ['nico.ritsche@gmail.com']

  spec.summary = 'Read API for the Yes event sourcing framework'
  spec.description = 'Read API for the Yes event sourcing framework'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main/yes-read-api"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/yes-read-api/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'api-pagination', '~> 5.0'
  spec.add_dependency 'pagy', '~> 6.0'
  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'yes-core'
  spec.add_dependency 'zeitwerk'
end
