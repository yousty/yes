# frozen_string_literal: true

RSpec.describe Yes::Core::CommandUtilities do
  subject(:instance) { described_class.new(context:, aggregate:, aggregate_id:) }

  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:aggregate_id) { SecureRandom.uuid }

  describe '#build_command' do
    subject { instance.build_command(command_name, payload) }

    let(:command_name) { :approve_documents }
    let(:payload) { { document_ids: 'xyz,abc', another: 'xyz' } }
    let(:command_class) { Test::User::Commands::ApproveDocuments::Command }

    it 'builds a command with the correct payload' do
      aggregate_failures do
        expect(subject).to be_a(command_class)
        expect(subject.user_id).to eq(aggregate_id)
      end
    end

    context 'when command class is not found' do
      let(:command_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Command class not found for nonexistent')
      end
    end
  end

  describe '#build_attribute_command' do
    subject { instance.build_attribute_command(attribute_name, payload) }

    let(:attribute_name) { :test_field }
    let(:payload) { { test_field: 'test value' } }
    let(:command_class) { Test::User::Commands::ChangeTestField::Command }

    before do
      # Add test_field attribute to the aggregate
      Test::User::Aggregate.attribute :test_field, :string, command: true
    end

    after do
      # Clean up test_field attribute
      Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                  Test::User::Aggregate.attributes.except(:test_field))
    end

    it 'builds a command with the correct payload' do
      aggregate_failures do
        expect(subject).to be_a(command_class)
        expect(subject.user_id).to eq(aggregate_id)
        expect(subject.test_field).to eq('test value')
      end
    end

    context 'when command class is not found' do
      let(:attribute_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Command class not found for change_nonexistent')
      end
    end

    context 'with aggregate attribute id command' do
      let(:attribute_name) { :location_id }
      let(:location_id) { SecureRandom.uuid }
      let(:payload) { { location_id: location_id } }
      let(:command_class) { Test::User::Commands::ChangeLocation::Command }

      before do
        # Add location attribute to the aggregate
        Test::User::Aggregate.attribute :location, :aggregate, command: true
      end

      after do
        # Clean up location attribute
        Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                    Test::User::Aggregate.attributes.except(:location))
      end

      it 'builds a command with the correct payload using the base command name' do
        aggregate_failures do
          expect(subject).to be_a(command_class)
          expect(subject.user_id).to eq(aggregate_id)
          expect(subject.location_id).to eq(location_id)
        end
      end
    end
  end

  describe '#fetch_attribute_guard_evaluator_class' do
    subject { instance.fetch_attribute_guard_evaluator_class(attribute_name) }

    let(:attribute_name) { :test_field }
    let(:guard_evaluator_class) { Test::User::Commands::ChangeTestField::GuardEvaluator }

    before do
      # Add test_field attribute to the aggregate
      Test::User::Aggregate.attribute :test_field, :string, command: true
    end

    after do
      # Clean up test_field attribute
      Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                  Test::User::Aggregate.attributes.except(:test_field))
    end

    it 'returns the correct guard evaluator class' do
      expect(subject).to eq(guard_evaluator_class)
    end

    context 'when guard evaluator class is not found' do
      let(:attribute_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Guard evaluator class not found for change_nonexistent')
      end
    end

    context 'with aggregate attribute id' do
      let(:attribute_name) { :location_id }
      let(:guard_evaluator_class) { Test::User::Commands::ChangeLocation::GuardEvaluator }

      before do
        # Add location attribute to the aggregate
        Test::User::Aggregate.attribute :location, :aggregate, context: 'Test', aggregate: 'Location', command: true
      end

      after do
        # Clean up location attribute
        Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                    Test::User::Aggregate.attributes.except(:location))
      end

      it 'returns the correct guard evaluator class using the base command name' do
        expect(subject).to eq(guard_evaluator_class)
      end
    end
  end

  describe '#fetch_guard_evaluator_class' do
    subject { instance.fetch_guard_evaluator_class(command_name) }

    let(:command_name) { :approve_documents }
    let(:guard_evaluator_class) { Test::User::Commands::ApproveDocuments::GuardEvaluator }

    it 'returns the correct guard evaluator class' do
      expect(subject).to eq(guard_evaluator_class)
    end

    context 'when guard evaluator class is not found' do
      let(:command_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Guard evaluator class not found for nonexistent')
      end
    end
  end
end
