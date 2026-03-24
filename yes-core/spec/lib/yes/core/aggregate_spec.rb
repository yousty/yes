# frozen_string_literal: true

require_relative '../../../support/shared_examples/shortcut_shared_examples'

RSpec.describe Yes::Core::Aggregate do
  # use Class.new to reset the class between tests
  let(:subject_class) { Test::User::Aggregate }

  describe '.parent' do
    context 'when command option is not provided' do
      subject { subject_class.parent(:test_parent, option: 'value') }

      after do
        # reset to not mess with further specs
        subject_class.instance_variable_set(:@parent_aggregates, {})
      end

      it 'adds parent to parent_aggregates' do
        expect { subject }.to change { subject_class.parent_aggregates[:test_parent] }.to(option: 'value')
      end

      it 'defines a command with proper payload to assign a parent' do
        subject

        expect(subject_class.commands[:assign_test_parent].payload_attributes).
          to eq(test_parent_id: :uuid)
      end

      context 'when a block is given' do
        subject do
          subject_class.parent(:test_parent, option: 'value') do
            guard(:unassigned) { test_parent_id.blank? }
            guard(:not_removed) { trashed_at.blank? }
          end
        end

        it 'yields the block' do
          subject

          expect(subject_class.commands[:assign_test_parent].guard_names).
            to match_array(%i[unassigned not_removed no_change])
        end
      end
    end

    context 'when command option is set to false' do
      subject { subject_class.parent(:test_parent_2, command: false) }

      after do
        # reset to not mess with further specs
        subject_class.instance_variable_set(:@parent_aggregates, {})
      end

      it 'does not define an assign command' do
        subject

        expect(subject_class.commands[:assign_test_parent_2]).to be_nil
      end
    end

    context 'when command option is set to true' do
      subject { subject_class.parent(:test_parent_3, command: true) }

      after do
        # reset to not mess with further specs
        subject_class.instance_variable_set(:@parent_aggregates, {})
      end

      it 'defines an assign command with proper payload to assign a parent' do
        subject

        expect(subject_class.commands[:assign_test_parent_3].payload_attributes).
          to eq(test_parent_3_id: :uuid)
      end
    end
  end

  describe '.parent_aggregates' do
    subject { subject_class.parent_aggregates }

    it 'returns an empty hash' do
      is_expected.to eq({})
    end
  end

  describe '.removable' do
    let(:attr_name) { :removed_at }
    let(:expected_state_updater) { Test::User::Commands::Remove::StateUpdater }

    subject { subject_class.removable(attr_name:) }

    after do
      subject_class.instance_variable_set(:@attributes, subject_class.attributes.except(attr_name))
      subject_class.instance_variable_set(:@commands, subject_class.commands.except(:remove))
    end

    context 'when attribute is undefined' do
      it 'defines default attribute removed_at as a datetime' do
        expect { subject }.to change { subject_class.attributes[attr_name] }.to(:datetime)
      end
    end

    context 'when attribute is defined' do
      before { subject_class.attribute(:removed_at, :year) }

      it 'does not overwrite the default removed_at attribute' do
        expect { subject }.not_to(change { subject_class.attributes[attr_name] })
      end
    end

    context 'when given custom attribute name' do
      let(:attr_name) { :deleted_at }

      it 'defines the custom attribute' do
        expect { subject }.to change { subject_class.attributes[attr_name] }.to(:datetime)
      end
    end

    it 'defines remove command with no_change guard' do
      subject

      expect(subject_class.commands[:remove].guard_names).to include(:no_change)
    end

    it 'defines remove command with state_updater' do
      subject

      aggregate_failures do
        expect(expected_state_updater.update_state_block).to be_present
        expect(expected_state_updater.updated_attributes).to eq([attr_name])
      end
    end

    context 'when block is given' do
      subject do
        subject_class.removable do
          guard(:exists) { read_model.exists? }
        end
      end

      it 'yields the block' do
        subject

        expect(subject_class.commands[:remove].guard_names).to include(:exists)
      end
    end
  end

  describe '.primary_context' do
    subject { subject_class.primary_context('TestContext') }

    it 'sets the primary context' do
      expect { subject }.to change { subject_class._primary_context }.to('TestContext')
    end
  end

  describe '#reload' do
    subject(:reload_call) { instance.reload }

    let(:instance) { subject_class.new }
    let(:read_model_double) { instance_double('ApplicationRecord') }

    before do
      allow(instance).to receive(:read_model).and_return(read_model_double)
      allow(read_model_double).to receive(:reload)
    end

    it 'reloads the read model' do
      reload_call
      expect(read_model_double).to have_received(:reload)
    end

    it 'returns the aggregate instance' do
      expect(reload_call).to eq(instance)
    end
  end

  describe '#latest_event' do
    subject(:latest_event) { instance.latest_event }

    let(:instance) { subject_class.new(aggregate_id) }
    let(:aggregate_id) { SecureRandom.uuid }
    let(:stream) { PgEventstore::Stream.new(context: 'Test', stream_name: 'User', stream_id: aggregate_id) }
    let(:event) do
      Yes::Core::Event.new(
        id: SecureRandom.uuid,
        type: 'Test::UserCreated',
        data: {},
        stream_revision: 5
      )
    end
    let(:client_double) { instance_double(PgEventstore::Client) }

    before do
      allow(instance).to receive(:command_utilities).and_return(
        instance_double('CommandUtilities', build_stream: stream)
      )
      allow(PgEventstore).to receive(:client).and_return(client_double)
    end

    it 'reads the latest event from the stream with correct options' do
      expect(client_double).to receive(:read).
        with(stream, options: { max_count: 1, direction: :desc }).
        and_return([event])

      expect(latest_event).to eq(event)
    end

    context 'when no events exist' do
      it 'returns nil' do
        expect(client_double).to receive(:read).
          with(stream, options: { max_count: 1, direction: :desc }).
          and_return([])

        expect(latest_event).to be_nil
      end
    end
  end

  describe '#event_revision' do
    subject(:event_revision) { instance.event_revision }

    let(:instance) { subject_class.new(SecureRandom.uuid) }
    let(:event) do
      Yes::Core::Event.new(
        id: SecureRandom.uuid,
        type: 'Test::UserCreated',
        data: {},
        stream_revision: 42
      )
    end

    before do
      allow(instance).to receive(:latest_event).and_return(event)
    end

    it 'returns the stream revision of the latest event' do
      expect(event_revision).to eq(42)
    end

    context 'when no events exist' do
      before do
        allow(instance).to receive(:latest_event).and_return(nil)
      end

      it 'raises NoMethodError' do
        expect { event_revision }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#commands' do
    subject(:commands) { instance.commands }

    let(:instance) { subject_class.new }

    it 'returns a hash of commands with their associated events' do
      expect(commands).to be_a(Hash)
    end

    it 'includes attribute-based commands defined on the aggregate' do
      expect(commands).to include(
        change_name: [:name_changed],
        change_email: [:email_changed],
        change_age: [:age_changed],
        change_active: [:active_changed]
      )
    end

    it 'includes custom commands with specified events' do
      expect(commands).to include(
        approve_documents: [:documents_approved],
        approve_documents_with_custom_event: [:document_happily_approved],
        some_custom_command: [:some_custom_event]
      )
    end

    it 'includes shortcut commands' do
      expect(commands).to include(
        publish: [:published],
        enable_shortcut_toggle: [:shortcut_toggle_enabled],
        disable_shortcut_toggle: [:shortcut_toggle_disabled],
        activate_shorcut_usage: [:shorcut_usage_activated],
        change_shortcut_description: [:shortcut_description_changed],
        change_shortcuts_used: [:shortcuts_used_changed]
      )
    end

    it 'includes locale-specific commands' do
      expect(commands).to include(
        test_command_with_locale: [:locale_test_changed]
      )
    end

    it 'returns commands in alphabetical order' do
      command_names = commands.keys
      expect(command_names).to eq(command_names.sort)
    end

    it 'retrieves command mappings from the global configuration' do
      expect(Yes::Core.configuration).to receive(:command_event_mappings).
        with('Test', 'User').
        and_call_original

      commands
    end

    context 'with an aggregate that has no commands' do
      let(:empty_aggregate_class) do
        Class.new(Yes::Core::Aggregate) do
          def self.name
            'EmptyContext::EmptyAggregate::Aggregate'
          end

          primary_context 'EmptyContext'
        end
      end

      let(:instance) { empty_aggregate_class.new }

      it 'returns an empty hash' do
        expect(commands).to eq({})
      end
    end
  end

  describe '.command' do
    after do
      # reset to not mess with further specs
      subject_class.instance_variable_set(:@attributes, {})
      subject_class.instance_variable_set(:@commands, {})
    end

    context 'when defining shortcut' do
      let(:subject_class) { Test::Comparison::AggregateA }

      context 'when it is a publish shortcut' do
        subject { subject_class.command(:publish, attribute: :article_published) }

        let(:expanded_code) do
          proc do
            attribute :article_published, :boolean
            command :publish do
              guard(:no_change) { !article_published }
              update_state { article_published { true } }
            end
          end
        end

        it_behaves_like 'expanded shortcut'
      end

      context 'when it is a toggle shortcut' do
        subject { subject_class.command(%i[enable disable], :dropout) }

        let(:expanded_code) do
          proc do
            attribute :dropout, :boolean
            command :enable_dropout do
              guard(:no_change) { !dropout }
              update_state { dropout { true } }
            end

            command :disable_dropout do
              guard(:no_change) { dropout }
              update_state { dropout { false } }
            end
          end
        end

        it_behaves_like 'expanded shortcut'
      end

      context 'when it is a enable shortcut' do
        subject { subject_class.command(:enable, :dropout) }

        let(:expanded_code) do
          proc do
            attribute :dropout, :boolean
            command :enable_dropout do
              guard(:no_change) { !dropout }
              update_state { dropout { true } }
            end
          end
        end

        it_behaves_like 'expanded shortcut'

        context 'with custom naming' do
          subject { subject_class.command(:activate, :dropout, attribute: :dropout_enabled) }

          let(:expanded_code) do
            proc do
              attribute :dropout_enabled, :boolean
              command :activate_dropout do
                guard(:no_change) { !dropout_enabled }
                update_state { dropout_enabled { true } }
              end
            end
          end

          it_behaves_like 'expanded shortcut'
        end
      end

      context 'when it is a change shortcut' do
        subject { subject_class.command(:change, :description, attribute: :article_description) }

        let(:expanded_code) do
          proc do
            attribute :article_description, :string
            command :change_description do
              payload article_description: :string
            end
          end
        end

        it_behaves_like 'expanded shortcut'

        context 'with custom type' do
          subject { subject_class.command(:change, :age, :integer) }

          let(:expanded_code) do
            proc do
              attribute :age, :integer
              command :change_age do
                payload age: :integer
              end
            end
          end

          it_behaves_like 'expanded shortcut'
        end

        context 'with custom block' do
          subject do
            subject_class.command :change, :age, :integer do
              guard(:test) { true }
            end
          end

          let(:expanded_code) do
            proc do
              attribute :age, :integer
              command :change_age do
                guard(:test) { true }
                payload age: :integer
              end
            end
          end

          it_behaves_like 'expanded shortcut'
        end

        context 'when attribute is set to false' do
          subject { subject_class.command(:change, :description, attribute: false) }

          let(:expanded_code) do
            proc do
              command :change_description do
                payload description: :string
              end
            end
          end
        end

        context 'when using localized versions' do
          subject { subject_class.command(:change, :description, localized: true) }

          let(:expanded_code) do
            proc do
              attribute :description, :string, localized: true
              command :change_description do
                payload description: :string, locale: :locale
              end
            end
          end

          it_behaves_like 'expanded shortcut'

          context 'with custom type' do
            subject { subject_class.command(:change, :age, :integer, localized: true) }

            let(:expanded_code) do
              proc do
                attribute :age, :integer, localized: true
                command :change_age do
                  payload age: :integer, locale: :locale
                end
              end
            end

            it_behaves_like 'expanded shortcut'
          end
        end

        context 'with encrypt option' do
          let(:encrypt_aggregate_class) do
            Class.new(Yes::Core::Aggregate) do
              def self.name
                'EncryptShortcut::User::Aggregate'
              end

              command :change, :ssn, :string, encrypt: true
            end
          end

          let(:event_class) { EncryptShortcut::User::Events::SsnChanged }
          let(:command_data) { encrypt_aggregate_class.commands[:change_ssn] }

          it 'populates encrypted_attributes in command_data' do
            expect(command_data.encrypted_attributes).to eq([:ssn])
          end

          it 'generates event with encryption_schema' do
            aggregate_failures do
              expect(event_class).to respond_to(:encryption_schema)
              expect(event_class.encryption_schema[:attributes]).to eq([:ssn])
            end
          end

          it 'encryption_schema key lambda returns correct aggregate_id' do
            aggregate_id = SecureRandom.uuid
            data = { user_id: aggregate_id, ssn: '123-45-6789' }

            expect(event_class.encryption_schema[:key].call(data)).to eq(aggregate_id)
          end
        end
      end
    end
  end

  describe 'inline payload encryption syntax' do
    let(:aggregate_class) do
      Class.new(Yes::Core::Aggregate) do
        def self.name
          'InlineEncryption::Contact::Aggregate'
        end

        attribute :email, :email
        attribute :phone, :string

        command :update_contact_info do
          payload email: { type: :email, encrypt: true }, phone: :string
        end
      end
    end

    let(:event_class) { InlineEncryption::Contact::Events::ContactInfoUpdated }
    let(:command_data) { aggregate_class.commands[:update_contact_info] }

    it 'tracks encrypted attributes from inline payload syntax' do
      expect(command_data.encrypted_attributes).to eq([:email])
    end

    it 'generates event with encryption_schema for inline encrypted fields' do
      aggregate_failures do
        expect(event_class).to respond_to(:encryption_schema)
        expect(event_class.encryption_schema[:attributes]).to eq([:email])
      end
    end

    it 'stores payload attributes with inline syntax' do
      expect(command_data.payload_attributes).to eq({ email: { type: :email }, phone: :string })
    end
  end

  describe 'separate encrypt DSL method' do
    let(:aggregate_class) do
      Class.new(Yes::Core::Aggregate) do
        def self.name
          'SeparateEncrypt::User::Aggregate'
        end

        attribute :email, :email
        attribute :phone, :string
        attribute :address, :string

        command :update_details do
          payload email: :email, phone: :string, address: :string
          encrypt :email, :phone
        end
      end
    end

    let(:event_class) { SeparateEncrypt::User::Events::DetailsUpdated }
    let(:command_data) { aggregate_class.commands[:update_details] }

    it 'tracks multiple encrypted attributes from encrypt DSL method' do
      expect(command_data.encrypted_attributes).to contain_exactly(:email, :phone)
    end

    it 'generates event with encryption_schema for DSL-declared encrypted fields' do
      aggregate_failures do
        expect(event_class).to respond_to(:encryption_schema)
        expect(event_class.encryption_schema[:attributes]).to contain_exactly(:email, :phone)
      end
    end
  end

  describe 'hybrid encryption syntax' do
    let(:aggregate_class) do
      Class.new(Yes::Core::Aggregate) do
        def self.name
          'Hybrid::Account::Aggregate'
        end

        attribute :ssn, :string
        attribute :email, :email
        attribute :phone, :string

        command :update_sensitive_data do
          payload ssn: { type: :string, encrypt: true }, email: :email, phone: :string
          encrypt :phone
        end
      end
    end

    let(:event_class) { Hybrid::Account::Events::SensitiveDataUpdated }
    let(:command_data) { aggregate_class.commands[:update_sensitive_data] }

    it 'combines inline and DSL encryption declarations' do
      expect(command_data.encrypted_attributes).to contain_exactly(:ssn, :phone)
    end

    it 'generates event with encryption_schema combining both approaches' do
      aggregate_failures do
        expect(event_class).to respond_to(:encryption_schema)
        expect(event_class.encryption_schema[:attributes]).to contain_exactly(:ssn, :phone)
      end
    end
  end
end
