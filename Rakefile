# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

require 'pg_eventstore'

load 'pg_eventstore/tasks/setup.rake'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[spec rubocop]
