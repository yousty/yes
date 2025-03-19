# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiner do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate:, command: true } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:user_id) { SecureRandom.uuid }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  let(:aggregate_instance) { aggregate_class.new }

  describe '#call' do
    # define a new attribute on the existing user aggregate
    subject { described_class.new(attribute_data).call }

    after do
      # Clean up standard attribute constants
      if Test::User::Commands.const_defined?(:ChangeTestField)
        Test::User::Commands.send(:remove_const, 'ChangeTestField')
      end
      Test::User::Events.send(:remove_const, :TestFieldChanged) if Test::User::Events.const_defined?(:TestFieldChanged)
      aggregate_class.remove_method(:change_test_field) if aggregate_class.method_defined?(:change_test_field)
      aggregate_class.remove_method(:can_change_test_field?) if aggregate_class.method_defined?(:can_change_test_field?)
      aggregate_class.remove_method(:test_field) if aggregate_class.method_defined?(:test_field)
    end

    context 'with standard attributes' do
      it 'creates and registers command, event, and guard evaluator classes' do
        aggregate_failures do
          expect { subject }.to change {
            Test::User::Commands.const_defined?('ChangeTestField::Command')
          }.from(false).to(true).
            and change {
                  Test::User::Events.const_defined?(:TestFieldChanged)
                }.from(false).to(true).
            and change {
                  Test::User::Commands.const_defined?('ChangeTestField::GuardEvaluator')
                }.from(false).to(true)
        end
      end

      context 'aggregate method definition' do
        before { subject }

        it 'defines a change method for the attribute' do
          expect(aggregate_instance).to respond_to(:change_test_field)
        end

        it 'defines a can_change...? method for the attribute' do
          expect(aggregate_instance).to respond_to(:can_change_test_field?)
        end

        it 'defines a reader method for the attribute' do
          expect(aggregate_instance).to respond_to(:test_field)
        end
      end
    end

    context 'when command option is not present or false' do
      let(:options) { { context:, aggregate: } }

      it 'does not define any command methods' do
        aggregate_failures do
          expect { subject }.not_to change {
            Test::User::Commands.const_defined?('ChangeTestField::Command')
          }.from(false)
          expect { subject }.not_to change {
            Test::User::Events.const_defined?(:TestFieldChanged)
          }.from(false)
          expect { subject }.not_to change {
            Test::User::Commands.const_defined?('ChangeTestField::GuardEvaluator')
          }.from(false)
        end
      end

      context 'aggregate method definition' do
        before { subject }

        it 'defines a reader method for the attribute' do
          expect(aggregate_instance).to respond_to(:test_field)
        end

        it 'does not define a change method for the attribute' do
          expect(aggregate_instance).not_to respond_to(:change_test_field)
        end

        it 'does not define a can_change...? method for the attribute' do
          expect(aggregate_instance).not_to respond_to(:can_change_test_field?)
        end
      end
    end

    context 'with aggregate attributes' do
      let(:attribute_name) { :location }
      let(:attribute_type) { :aggregate }

      after do
        # Clean up aggregate attribute constants
        if Test::User::Commands.const_defined?(:ChangeLocation)
          Test::User::Commands.send(:remove_const, 'ChangeLocation')
        end
        Test::User::Events.send(:remove_const, :LocationChanged) if Test::User::Events.const_defined?(:LocationChanged)
      end

      it 'creates and registers command, event, and guard evaluator classes' do
        aggregate_failures do
          expect { subject }.to change {
            Test::User::Commands.const_defined?('ChangeLocation::Command')
          }.from(false).to(true).
            and change {
                  Test::User::Events.const_defined?(:LocationChanged)
                }.from(false).to(true).
            and change {
                  Test::User::Commands.const_defined?('ChangeLocation::GuardEvaluator')
                }.from(false).to(true)
        end
      end

      context 'aggregate method definition' do
        before { subject }

        context 'change command methods' do
          it 'defines both change methods for the attribute' do
            aggregate_failures do
              expect(aggregate_instance).to respond_to(:change_location)
              expect(aggregate_instance).to respond_to(:change_location_id)
            end
          end
        end

        context 'can_change...? command method' do
          it 'defines both can_change methods for the attribute' do
            aggregate_failures do
              expect(aggregate_instance).to respond_to(:can_change_location?)
              expect(aggregate_instance).to respond_to(:can_change_location_id?)
            end
          end
        end

        context 'attribute accessor methods' do
          it 'defines both reader methods for the attribute' do
            aggregate_failures do
              expect(aggregate_instance).to respond_to(:location)
              expect(aggregate_instance).to respond_to(:location_id)
            end
          end
        end
      end
    end
  end
end
