# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::CommandDefiner do
  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      command_name,
      aggregate_class,
      context: 'Test',
      aggregate: 'User'
    )
  end

  let(:aggregate_class) { Test::User::Aggregate }
  let(:aggregate) { aggregate_class.new }
  let(:command_name) { :confirm_booking }
  let(:command_module_name) { 'ConfirmBooking' }
  let(:event_class_name) { 'BookingConfirmed' }

  after do
    # Clean up constants
    if Test::User::Commands.const_defined?(command_module_name)
      Test::User::Commands.send(:remove_const, command_module_name)
    end
    Test::User::Events.send(:remove_const, event_class_name) if Test::User::Events.const_defined?(event_class_name)
  end

  shared_examples 'a command' do
    it 'creates and registers command, event, and guard evaluator classes' do
      aggregate_failures do
        expect { subject }.to change {
          Test::User::Commands.const_defined?("#{command_module_name}::Command")
        }.from(false).to(true).
          and change {
                Test::User::Events.const_defined?(event_class_name)
              }.from(false).to(true).
          and change {
                Test::User::Commands.const_defined?("#{command_module_name}::GuardEvaluator")
              }.from(false).to(true)
      end
    end

    context 'command method' do
      it 'defines a command method' do
        subject
        expect(aggregate).to respond_to(command_name)
      end
    end

    context 'can_<command>? command method' do
      it 'defines a can_<command>? method' do
        subject
        expect(aggregate).to respond_to("can_#{command_name}?")
      end
    end
  end

  describe '#call' do
    # define a new command on the existing user aggregate
    subject { described_class.new(command_data).call }

    context 'without customizations' do
      it_behaves_like 'a command'
    end

    context 'with custom payload attributes' do
      subject do
        described_class.new(command_data).call do
          payload blah_blah: :integer
        end
      end

      context 'when attribute is not defined on the aggregate' do
        it 'raises an error' do
          expect { subject }.to raise_error(Yes::Core::Aggregate::Dsl::CommandDefiner::UndefinedAttributeError)
        end
      end

      context 'when attribute is defined on the aggregate' do
        before do
          aggregate_class.attribute :blah_blah, :integer
        end

        it_behaves_like 'a command'
      end
    end

    context 'with custom event name' do
      subject do
        event_name = custom_event_name
        described_class.new(command_data).call do
          event event_name
        end
      end

      let(:custom_event_name) { :booking_happily_confirmed }

      it 'defines an event with the custom name' do
        expect { subject }.to change {
          Test::User::Events.const_defined?(custom_event_name.to_s.camelize)
        }.from(false).to(true)
      end
    end

    context 'with custom state update' do
      context 'when updated attribute is not defined on the aggregate' do
        subject do
          described_class.new(command_data).call do
            update_state do
              blah_blub { "#{payload[:huhu]}@xyz.ch" }
            end
          end
        end

        it 'raises an error' do
          expect { subject }.to raise_error(Yes::Core::Aggregate::Dsl::CommandDefiner::UndefinedAttributeError)
        end
      end
    end
  end
end
