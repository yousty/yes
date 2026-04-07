# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'pg_eventstore'

load 'pg_eventstore/tasks/setup.rake'

GEMS = %w[yes-core yes-command-api yes-read-api].freeze

GEMS.each do |gem_name|
  namespace gem_name.tr('-', '_') do
    desc "Run #{gem_name} specs"
    task spec: :environment do
      Dir.chdir(gem_name) do
        Bundler.with_unbundled_env do
          sh 'bundle exec rspec spec'
        end
      end
    end
  end
end

desc 'Run specs for all gems'
task spec: GEMS.map { |g| "#{g.tr('-', '_')}:spec" }

task default: :spec
