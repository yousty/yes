# frozen_string_literal: true

require_relative "lib/yes/version"

Gem::Specification.new do |spec|
  spec.name = "yes"
  spec.version = Yes::VERSION
  spec.authors = ["ncri"]
  spec.email = ["nico.ritsche@gmail.com"]

  spec.summary = "Yes"
  spec.description = "Yes"
  spec.homepage = "https://github.com/yousty/yes"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1")

  spec.metadata["allowed_push_host"] = "https://gem.fury.io/yousty-ag/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'yousty-eventsourcing', '>= 11'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
