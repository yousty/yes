# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate do
  let(:aggregate_class) { Test::User::Aggregate }

  after do
    # Clean up state between tests to avoid cross-test pollution
    aggregate_class._read_model_enabled = true
  end

  describe '.read_model' do
    subject { aggregate_class.read_model 'custom_model' }

    before do
      subject
    end

    it 'sets custom read model name' do
      expect(aggregate_class.read_model_name).to eq('custom_model')
    end

    context 'when public is not provided' do
      it 'sets read model visibility to true' do
        expect(aggregate_class.read_model_public?).to be true
      end
    end

    context 'when public is false' do
      subject { aggregate_class.read_model 'custom_model', public: false }
      it 'sets read model visibility to false' do
        expect(aggregate_class.read_model_public?).to be false
      end
    end

    context 'when public is true' do
      subject { aggregate_class.read_model 'custom_model', public: true }

      it 'sets read model visibility to true' do
        expect(aggregate_class.read_model_public?).to be true
      end
    end

    context 'when false is passed' do
      subject { aggregate_class.read_model false }

      it 'disables read model' do
        expect(aggregate_class.read_model_enabled?).to be false
      end
    end
  end

  describe '.read_model_enabled?' do
    before do
      # Ensure we start with a clean state
      aggregate_class._read_model_enabled = true
    end

    context 'when read_model is not disabled' do
      it 'returns true by default' do
        expect(aggregate_class.read_model_enabled?).to be true
      end
    end

    context 'when read_model is disabled' do
      before do
        aggregate_class.read_model false
      end

      it 'returns false' do
        expect(aggregate_class.read_model_enabled?).to be false
      end
    end
  end

  describe 'attribute changes' do
    subject { aggregate.change_name(name: 'New Name') }
    let(:aggregate) { aggregate_class.new }

    before do
      # reset default read model name and re-enable if it was disabled
      aggregate_class._read_model_enabled = true
      aggregate_class.read_model 'user'
    end

    context 'when attribute change is allowed' do
      before do
        allow(aggregate).to receive(:update_read_model)
      end

      it 'updates read model after successful attribute change' do
        subject
        expect(aggregate).to have_received(:update_read_model).with(name: 'New Name', revision: 0, locale: nil, pending_update_since: nil)
      end
    end

    context 'when attribute change is not allowed' do
      before do
        allow(aggregate).to receive(:update_read_model)
        allow_any_instance_of(Yes::Core::CommandHandling::CommandExecutor)
          .to receive(:call)
          .and_return(double('CommandResponse', success?: false))
      end

      it 'does not update read model' do
        subject
        expect(aggregate).not_to have_received(:update_read_model)
      end
    end

    context 'when read_model is disabled' do
      let(:aggregate_with_no_read_model_class) do
        Class.new(Yes::Core::Aggregate) do
          def self.name
            'Test::NoReadModel::Aggregate'
          end

          def self.context
            'Test'
          end

          def self.aggregate
            'NoReadModel'
          end

          primary_context 'Test'

          read_model false

          attribute :name, :string, command: true
        end
      end

      let(:aggregate) { aggregate_with_no_read_model_class.new }

      it 'does not attempt to update read model' do
        expect(aggregate).not_to receive(:update_read_model)

        # read_model will be called by the accessor but will return nil
        aggregate.change_name(name: 'Test Name')
      end

      it 'successfully executes command without read model' do
        response = aggregate.change_name(name: 'Test Name')
        expect(response.success?).to be true
      end

      it 'read_model returns nil when disabled' do
        expect(aggregate.read_model).to be_nil
      end

      it 'attribute accessors return nil when read model disabled' do
        expect(aggregate.name).to be_nil
      end
    end
  end
end
