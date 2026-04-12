# frozen_string_literal: true

module Yes
  module Core
    module TestSupport
      module Aggregate
        # DSL for writing concise aggregate command specs.
        #
        # Provides `command`, `success`, `invalid`, `no_change`, and `setup` methods
        # that generate RSpec describe/context blocks with appropriate shared examples.
        #
        # @example
        #   RSpec.describe MyContext::MyAggregate::Aggregate, type: :aggregate do
        #     command 'do_something' do
        #       let(:command_data) { { name: 'test' } }
        #       let(:success_attributes) { { name: 'test' } }
        #
        #       success
        #       invalid 'when precondition not met'
        #       no_change
        #     end
        #   end
        module CommandTestDsl
          # Defines a test block for a command
          #
          # @param command_name [String, Symbol] the name of the command to test
          # @param options [Array<Hash>] additional options (e.g., `draft: true`, VCR cassettes)
          # @yield block for configuring test cases with success/invalid/no_change
          def command(command_name, *options, &block)
            describe command_name.to_s, *options do
              let(:draft) { options.first&.dig(:draft) }

              let(:aggregate) { described_class.new(draft:) } unless method_defined?(:aggregate)

              subject { aggregate.public_send(command, command_data, guards: !draft) }

              let(:command) { command_name.to_sym }
              let(:aggregate_class) { aggregate.class }
              let(:command_data_with_id) do
                { "#{aggregate_class.aggregate.underscore}_id" => aggregate.id }.merge(command_data)
              end
              let(:command_data) { {} }
              let(:expected_event_type) do
                "#{aggregate_class.context}::#{aggregate_class.aggregate}" \
                  "#{'Draft' if draft}#{aggregate_class.commands[command].event_name.to_s.classify}"
              end
              let(:expected_event_data) { command_data_with_id }
              let(:expected_event_metadata) { nil }
              let(:success_attributes) { command_data.without(:locale) } unless method_defined?(:success_attributes)

              class_eval(&block) if block_given?
            end
          end

          # Defines a test case for a successful command execution
          #
          # @param description [String] optional description
          # @param options [Hash] additional options (e.g., VCR cassettes)
          # @yield optional block for additional setup or custom assertions
          def success(description = 'when successfully executing command', options = {}, &block)
            context description, options do
              instance_eval(&block) if block_given?

              it_behaves_like 'successful command'
            end
          end

          # Defines a test case for a command that causes no state change
          #
          # @param description [String] optional description
          # @param options [Hash] additional options
          # @yield optional block for additional setup
          def no_change(description = 'when command causes no change', options = {}, &block)
            context description.to_s, options do
              instance_eval(&block) if block_given?

              before { aggregate.public_send(command, command_data) }

              it_behaves_like 'no change transition'
            end
          end

          # Defines a test case for an invalid transition
          #
          # @param description [String] description of the invalid scenario
          # @param options [Hash] additional options
          # @yield optional block for additional setup
          def invalid(description, options = {}, &block)
            context "when #{description}", options do
              instance_eval(&block) if block_given?

              it_behaves_like 'invalid transition'
            end
          end

          # Alias for `before` — used for readable aggregate setup within command blocks
          #
          # @yield block for setup actions
          def setup(&)
            before(&)
          end
        end
      end
    end
  end
end

if defined?(RSpec)
  RSpec.configure do |config|
    config.extend Yes::Core::TestSupport::Aggregate::CommandTestDsl, type: :aggregate
  end
end
