# frozen_string_literal: true

require_relative 'lib/yes/auth/version'

Gem::Specification.new do |spec|
  spec.name = 'yes-auth'
  spec.version = Yes::Auth::VERSION
  spec.authors = ['Nico Ritsche']
  spec.email = ['nico.ritsche@yousty.ch']

  spec.summary = 'Authorization principals for the Yes event sourcing framework'
  spec.description = 'Provides authorization principal models (User, Role, ResourceAccess) and Cerbos integration for the Yes framework'
  spec.homepage = 'https://github.com/yousty/yes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main/yes-auth"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/yes-auth/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # The auth_principals_* factories are part of this gem's public test-support
  # surface: an application that authorizes through yes-auth needs principals,
  # roles and resource-access rows to write its own specs against, and those
  # tables belong to this gem. They are shipped so that a released gem behaves
  # like a git checkout — an application loads them explicitly by path, e.g.
  #
  #   factories = Pathname.new(Gem.loaded_specs['yes-auth'].full_gem_path)
  #                       .join('spec', 'factories')
  #   factories.glob('auth_principals_*.rb').each { |f| load f }
  #
  # `spec/factories/dummy_resources.rb` is deliberately NOT shipped: it defines
  # generic :company / :apprenticeship / :location factories for this gem's own
  # dummy app, which would collide with an application's factories of the same name.
  spec.files = Dir['{lib}/**/*', 'spec/factories/auth_principals_*.rb', 'LICENSE.txt', 'README.md',
                   'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.1'
  spec.add_dependency 'yes-core', '~> 2.0'
end
