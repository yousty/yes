# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiner do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
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
      aggregate_class.remove_method(:test_field) if aggregate_class.method_defined?(:test_field)
    end

    context 'with standard attributes' do
      context 'aggregate method definition' do
        before { subject }

        it 'defines a reader method for the attribute' do
          expect(aggregate_instance).to respond_to(:test_field)
        end
      end

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

      context 'aggregate method definition' do
        before { subject }

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

    context 'with encrypted attribute' do
      subject { aggregate_class.attribute(:encrypted_field, :string, encrypted: true) }

      it 'stores the encrypted option in attribute_options' do
        subject
        expect(aggregate_class.attribute_options[:encrypted_field][:encrypted]).to be true
      end

      after do
        # Remove only the attribute we added, not the entire hash
        aggregate_class.attribute_options.delete(:encrypted_field)
        aggregate_class.attributes.delete(:encrypted_field)
        aggregate_class.remove_method(:encrypted_field) if aggregate_class.method_defined?(:encrypted_field)
      end
    end
  end
end
