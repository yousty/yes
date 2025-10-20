# frozen_string_literal: true

RSpec.describe Yes::Core::Configuration do
  let(:context_name) { :sales }
  let(:aggregate_name) { :user }
  let(:action_name) { :create }
  let(:test_class) { Class.new }
  let(:configuration) { described_class.new }

  describe '.configuration' do
    subject { Yes::Core.configuration }

    it 'returns the configuration singleton' do
      aggregate_failures do
        expect(subject).to be_a(described_class)
        expect(subject).to eq(Yes::Core.configuration)
      end
    end
  end

  describe '#register_command_class' do
    subject { configuration.register_command_class(context_name, aggregate_name, action_name, test_class) }

    it 'registers the command class' do
      subject
      expect(configuration.aggregate_class(context_name, aggregate_name, action_name, :command)).to eq(test_class)
    end
  end

  describe '#register_event_class' do
    subject { configuration.register_event_class(context_name, aggregate_name, action_name, test_class) }

    it 'registers the event class' do
      subject
      expect(configuration.aggregate_class(context_name, aggregate_name, action_name, :event)).to eq(test_class)
    end
  end

  describe '#register_guard_evaluator_class' do
    subject { configuration.register_guard_evaluator_class(context_name, aggregate_name, action_name, test_class) }

    it 'registers the guard evaluator class' do
      subject
      expect(configuration.aggregate_class(context_name, aggregate_name, action_name,
                                           :guard_evaluator)).to eq(test_class)
    end
  end

  describe '#register_read_model_class' do
    subject { configuration.register_read_model_class(context_name, aggregate_name, test_class, draft:) }

    context 'when draft is false' do
      let(:draft) { false }

      it 'registers the class under :read_model key' do
        subject
        expect(configuration.aggregate_class(context_name, aggregate_name, nil, :read_model)).to eq(test_class)
      end

      it 'does not register under :draft_read_model key' do
        subject
        expect(configuration.aggregate_class(context_name, aggregate_name, nil, :draft_read_model)).not_to eq(test_class)
      end
    end

    context 'when draft is true' do
      let(:draft) { true }

      it 'registers the class under :draft_read_model key' do
        subject
        expect(configuration.aggregate_class(context_name, aggregate_name, nil, :draft_read_model)).to eq(test_class)
      end

      it 'does not register under :read_model key' do
        subject
        expect(configuration.aggregate_class(context_name, aggregate_name, nil, :read_model)).not_to eq(test_class)
      end
    end

    context 'when draft is not specified (default)' do
      subject { configuration.register_read_model_class(context_name, aggregate_name, test_class) }

      it 'registers the class under :read_model key by default' do
        subject
        expect(configuration.aggregate_class(context_name, aggregate_name, nil, :read_model)).to eq(test_class)
      end
    end
  end

  describe '#aggregate_class' do
    subject { configuration.aggregate_class(context_name, aggregate_name, action_name, :command) }

    context 'when class is registered' do
      before { configuration.register_command_class(context_name, aggregate_name, action_name, test_class) }

      it { is_expected.to eq(test_class) }
    end
  end

  describe '#aggregate_class' do
    subject { configuration.aggregate_class(context_name, aggregate_name, action_name, :command) }

    context 'when class is registered' do
      before { configuration.register_command_class(context_name, aggregate_name, action_name, test_class) }

      it { is_expected.to eq(test_class) }
    end

    context 'when class is not registered' do
      it { is_expected.to be_nil }
    end
  end

  describe '#list_aggregate_classes' do
    subject { configuration.list_aggregate_classes(context_name, aggregate_name) }

    before do
      configuration.register_command_class(context_name, aggregate_name, :create, test_class)
      configuration.register_event_class(context_name, aggregate_name, :created, test_class)
    end

    it 'returns the registered classes' do
      aggregate_failures do
        expect(subject).to include(command: { create: test_class }, event: { created: test_class })
        expect(subject[:handler]).to be_empty
      end
    end
  end

  describe '#list_all_registered_classes' do
    subject { configuration.list_all_registered_classes }

    let(:another_aggregate) { :order }

    before do
      configuration.register_command_class(context_name, aggregate_name, :create, test_class)
      configuration.register_event_class(context_name, another_aggregate, :created, test_class)
    end

    it do
      is_expected.to eq({
                          [context_name, aggregate_name] => { command: { create: test_class } },
                          [context_name, another_aggregate] => { event: { created: test_class } }
                        })
    end
  end

  describe 'plural model name handling' do
    describe '#all_read_model_class_names' do
      context 'with plural model names' do
        before do
          # Register a test aggregate with plural name - need all 5 params
          configuration.register_aggregate_class(:test, :company_settings, :dummy_action, :command, test_class)
          
          # Mock the aggregate class
          aggregate_class = double('TestCompanySettingsAggregate')
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('company_settings')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          allow(Object).to receive(:const_get).with('Test::CompanySettings::Aggregate').and_return(aggregate_class)
        end

        it 'preserves plural names when using camelize instead of classify' do
          class_names = configuration.all_read_model_class_names
          
          # Should be CompanySettings (plural), not CompanySetting (singular)
          expect(class_names).to include('CompanySettings')
          expect(class_names).not_to include('CompanySetting')
        end
      end

      context 'with singular model names' do
        before do
          # Register a test aggregate with singular name - need all 5 params
          configuration.register_aggregate_class(:test, :user, :dummy_action, :command, test_class)
          
          # Mock the aggregate class
          aggregate_class = double('TestUserAggregate')
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('user')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          allow(Object).to receive(:const_get).with('Test::User::Aggregate').and_return(aggregate_class)
        end

        it 'handles singular names correctly with camelize' do
          class_names = configuration.all_read_model_class_names
          
          # Should be User (singular remains singular)
          expect(class_names).to include('User')
        end
      end

      context 'with mixed plural/singular compound names' do
        before do
          # Register aggregates with compound names - need all 5 params
          configuration.register_aggregate_class(:company_management, :user_settings, :dummy_action, :command, test_class)
          
          # Mock the aggregate class
          aggregate_class = double('CompanyManagementUserSettingsAggregate')
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('company_management_user_settings')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          allow(Object).to receive(:const_get).with('CompanyManagement::UserSettings::Aggregate').and_return(aggregate_class)
        end

        it 'preserves plurality in compound names' do
          class_names = configuration.all_read_model_class_names
          
          # Should preserve UserSettings as plural
          expect(class_names).to include('CompanyManagementUserSettings')
          expect(class_names).not_to include('CompanyManagementUserSetting')
        end
      end
    end

    describe '#all_read_models_with_aggregate_classes' do
      context 'with plural model names' do
        before do
          # Register a test aggregate - need all 5 params
          configuration.register_aggregate_class(:test, :company_settings, :dummy_action, :command, test_class)
          
          # Mock the aggregate class
          aggregate_class = Class.new
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('company_settings')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          # Mock the read model class
          read_model_class = Class.new
          
          allow(Object).to receive(:const_get).with('Test::CompanySettings::Aggregate').and_return(aggregate_class)
          allow(Object).to receive(:const_get).with('CompanySettings').and_return(read_model_class)
        end

        it 'correctly resolves plural read model classes' do
          mappings = configuration.all_read_models_with_aggregate_classes
          
          expect(mappings).not_to be_empty
          expect(mappings.first[:read_model_class]).to be_a(Class)
        end
      end
    end
  end
end
