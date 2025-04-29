require_relative 'lib/yes/command/api/version'

Gem::Specification.new do |spec|
  spec.name        = 'yes-command-api'
  spec.version     = Yes::Command::Api::VERSION
  spec.authors     = ['Nico Ritsche']
  spec.email       = ['nico.ritsche@gmail.com']
  spec.homepage    = 'https://github.com/yousty/yes'
  spec.summary     = 'Command API for the Yes eventsourced microservice architecture.'
  spec.description = 'Command API for the Yes eventsourced microservice architecture.'
  spec.license     = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1')

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = "https://#{ENV.fetch('GEM_FURY_PUSH_TOKEN', nil)}@push.fury.io/yousty-ag/"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/yousty/yes'
  spec.metadata['changelog_uri'] = 'https://github.com/yousty/yes/blob/master/CHANGELOG.md'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'jwt_token_auth_client_rails', '~> 3.3'
  spec.add_dependency 'rails', '>= 7.0.4.3'
  spec.add_dependency 'yousty-eventsourcing', '>= 7'

  spec.add_development_dependency 'dotenv-rails', '~> 2.8'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'redis', '~> 5.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails', '~> 6.0.2'
  spec.add_development_dependency 'sidekiq', '~> 7.1'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'simplecov-formatter-badge', '~> 0.1'
  spec.add_development_dependency 'yousty_dev_tools', '~> 0.2'
  spec.add_development_dependency 'yousty_tools', '~> 0.4'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
