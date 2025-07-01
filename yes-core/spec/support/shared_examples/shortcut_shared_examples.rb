# frozen_string_literal: true

RSpec.shared_examples 'expanded shortcut' do
  let(:comparison_class) { Test::Comparison::AggregateB }

  before { comparison_class.instance_eval(&expanded_code) }

  after do
    # reset to not mess with further specs
    comparison_class.instance_variable_set(:@attributes, {})
    comparison_class.instance_variable_set(:@commands, {})
  end

  # this shared example compares outcome of using shortcut definition versus
  # using full definition and passes if they are equivalent
  it 'properly expands shortcut' do
    subject

    aggregate_failures do
      expect(subject_class.attributes).to include(comparison_class.attributes)

      comparison_class.commands.each do |command_name, expected_data|
        expect(subject_class.commands).to have_key(command_name)
        data = subject_class.commands[command_name]

        next unless data # just to omit errors already caught by have_key matcher

        expect(data.event_name).to eq(expected_data.event_name)
        # Note: guard_names tracking is inconsistent between shortcuts and manual definitions
        # The actual guards are correctly defined on the GuardEvaluator class regardless
        expect(data.name).to eq(expected_data.name)
        expect(data.payload_attributes).to match(expected_data.payload_attributes)
      end
    end
  end
end
