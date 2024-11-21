# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::Attribute do
  let(:context) { 'TestContext' }
  let(:aggregate) { 'TestAggregate' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { TestContext::TestAggregate }

  before do
    Object.const_set(:TestContext, Module.new)
    TestContext.const_set(:TestAggregate, Class.new(Yes::Aggregate))
  end

  describe '.define' do
    subject { described_class.define(attribute_name, attribute_type, aggregate_class, **options) }

    after do
      Object.send(:remove_const, :TestContext) if Object.const_defined?(:TestContext)
    end

    it 'creates and registers command, event, and handler classes' do
      expect { subject }.to change {
        Object.const_defined?('TestContext::TestAggregate::Commands::ChangeTestField::Command')
      }.from(false).to(true).
        and change {
              Object.const_defined?('TestContext::TestAggregate::Events::TestFieldChanged')
            }.from(false).to(true).
        and change {
              Object.const_defined?('TestContext::TestAggregate::Commands::ChangeTestField::Handler')
            }.from(false).to(true)
    end

    context 'change command method' do
      let(:command_payload) { { test_field: 'New Value' } }
      let(:handler_class) { TestContext::TestAggregate::Commands::ChangeTestField::Handler }

      it 'defines a change method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:change_test_field)
      end

      describe '#change_test_field' do
        subject { aggregate_class.new.change_test_field(**command_payload) }

        let(:handler_instance) { instance_double(handler_class) }
        let(:attribute_setup) do
          described_class.define(attribute_name, attribute_type, aggregate_class, **options)
        end

        before do
          attribute_setup

          allow(handler_class).to receive(:new).and_return(handler_instance)
          allow(handler_instance).to receive(:call)
          allow(handler_instance).to receive(:revision_check)
        end

        it 'instantiates and calls the handler with the command' do
          subject

          # one for can... check, one for actual handler call
          expect(handler_instance).to have_received(:call).exactly(2).times
        end
      end
    end

    context 'can_change...? command method' do
      let(:command_payload) { { test_field: 'test value' } }
      let(:handler_class) { TestContext::TestAggregate::Commands::ChangeTestField::Handler }
      let(:test_aggregate_id) { SecureRandom.uuid }

      it 'defines a can_change...? method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:can_change_test_field?)
      end

      describe '#can_change_test_field?' do
        subject { aggregate_instance.can_change_test_field?(**command_payload) }
        let(:aggregate_instance) { aggregate_class.new }

        before do
          described_class.define(attribute_name, attribute_type, aggregate_class, **options)
        end

        it 'returns true when the command is valid' do
          expect(subject).to be true
        end

        context 'when command validation fails' do
          before do
            # provoke a no change transition error
            aggregate_instance.change_test_field(**command_payload)
          end

          it 'returns false' do
            expect(subject).to be false
          end

          it 'sets the error on the aggregate' do
            subject
            expect(aggregate_instance.test_field_change_error).to eq('Test field is not changing')
          end
        end
      end
    end
  end

  describe '#generate_command_class' do
    subject do
      described_class.new(attribute_name, attribute_type, TestContext::TestAggregate,
                          options).send(:generate_command_class)
    end

    let(:test_aggregate_id) { SecureRandom.uuid }

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'generates a command class with correct attributes' do
      command_class = subject

      expect(command_class.superclass).to eq(Yes::Command)
      expect(command_class.schema.key?(:test_aggregate_id)).to be true
      expect(command_class.schema.key?(:test_field)).to be true
    end

    it 'defines subject_id alias method' do
      command_class = subject
      command = command_class.new(test_aggregate_id:, test_field: 'value')

      expect(command.subject_id).to eq(test_aggregate_id)
    end
  end

  describe '#generate_event_class' do
    subject do
      described_class.new(attribute_name, attribute_type, TestContext::TestAggregate,
                          options).send(:generate_event_class)
    end

    let(:test_aggregate_id) { SecureRandom.uuid }
    let(:test_field) { 'value' }

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'generates an event class with correct schema' do
      event_class = subject
      event = event_class.new(data: { test_aggregate_id:, test_field: })
      schema = event.schema

      expect(schema.rules.keys).to include(:test_aggregate_id, :test_field)
    end
  end

  describe '#generate_handler_class' do
    subject do
      described_class.new(attribute_name, attribute_type, TestContext::TestAggregate,
                          options).send(:generate_handler_class)
    end

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'generates a handler class with correct event name' do
      handler_class = subject

      expect(handler_class.event_name).to eq('TestFieldChanged')
    end

    it 'defines check method for no-change validation' do
      handler_class = subject

      expect(handler_class.instance_methods).to include(:check_test_field_is_not_changing)
    end
  end
end
