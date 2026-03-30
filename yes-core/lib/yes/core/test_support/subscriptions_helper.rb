# frozen_string_literal: true

require 'rspec/support/spec/in_sub_process'
require 'rspec/support/spec/stderr_splitter'

ENV['GRPC_ENABLE_FORK_SUPPORT'] = '1' if defined?(GRPC)

module Yes
  module Core
    module TestSupport
      # RSpec helper for asserting that PgEventstore subscriptions start correctly.
      #
      # @example
      #   RSpec.describe 'Subscriptions' do
      #     include Yes::Core::TestSupport::SubscriptionsHelper
      #
      #     it 'starts all subscriptions' do
      #       assert_running_subscriptions('eventstore/subscriptions.rb', 5)
      #     end
      #   end
      module SubscriptionsHelper
        include ::RSpec::Support::InSubProcess

        # Asserts that the expected number of subscriptions are running.
        #
        # @param subscriptions_paths [Array<String>] relative paths to subscription files
        # @param number_of_subscriptions [Integer] expected number of running subscriptions
        # @param root [String] root directory of subscription files
        # @param timeout [Integer] timeout in seconds for subscriptions to start
        # @return [void]
        def assert_running_subscriptions(*subscriptions_paths, number_of_subscriptions, root: './lib/tasks', timeout: 5)
          GRPC.prefork if defined?(GRPC)
          in_sub_process do
            GRPC.postfork_child if defined?(GRPC)
            require 'pg_eventstore/cli'
            PgEventstore.logger = Logger.new($stdout)
            PgEventstore.logger.level = :error
            require_options = subscriptions_paths.flat_map do |path|
              ['-r', "#{root}/#{path}"]
            end
            runner = Thread.new do
              PgEventstore::CLI.execute(['subscriptions', 'start', *require_options])
            end
            subscriptions_count = nil
            timeout = timeout.seconds.from_now
            loop do
              subscriptions_count = PgEventstore.connection.with do |c|
                c.exec(<<~SQL.squish)
                  select count(*) filter (where state = 'running') as count_running, count(*) as count_all
                    from subscriptions
                SQL
              end.first
              break if subscriptions_count['count_running'] == number_of_subscriptions || Time.current > timeout

              sleep 0.1
            end

            runner.exit
            aggregate_failures do
              expect(subscriptions_count['count_running']).to eq(number_of_subscriptions)
              expect(subscriptions_count['count_all']).to eq(number_of_subscriptions)
            end
          rescue StandardError => e
            Rails.logger.debug e.message
            Rails.logger.debug e.backtrace
            raise e
          end
          nil
        ensure
          GRPC.postfork_parent if defined?(GRPC)
        end
      end
    end
  end
end
