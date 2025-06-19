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
      end
    end
  end
end
