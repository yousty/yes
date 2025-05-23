# frozen_string_literal: true

RSpec.describe Yes::Core::ErrorMessages do
  describe '.guard_error' do
    subject { described_class.guard_error(context_name, aggregate_name, command_name, guard_name) }

    let(:context_name) { 'test' }
    let(:aggregate_name) { 'user' }
    let(:command_name) { 'test_command' }
    let(:guard_name) { :test_guard }
    let(:custom_error_message) { 'This is a custom error message for the test guard' }

    after do
      # Clean up translations
      I18n.backend.reload!
    end

    context 'with real I18n translations' do
      before do
        # Set up I18n translations for testing
        I18n.backend.store_translations(
          :"de-CH", {
            aggregates: {
              test: {
                user: {
                  commands: {
                    test_command: {
                      guards: {
                        test_guard: {
                          error: custom_error_message
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        )
      end

      it 'returns the correct translation from I18n' do
        expect(subject).to eq(custom_error_message)
      end

      context 'when the guard name is not found' do
        let(:guard_name) { :unknown_guard }

        it 'returns the default message for guards without translations' do
          expect(subject).to eq("Guard 'unknown_guard' failed")
        end
      end
    end

    context 'with different naming conventions' do
      let(:context_name) { 'TestContext' }
      let(:aggregate_name) { 'UserAggregate' }
      let(:command_name) { 'CreateUserCommand' }
      let(:guard_name) { 'EmailFormat' }
      let(:custom_error_message) { 'Email format is invalid' }

      before do
        # Set up I18n translations for testing with underscored keys
        I18n.backend.store_translations(
          :"de-CH", {
            aggregates: {
              test_context: {
                user_aggregate: {
                  commands: {
                    create_user_command: {
                      guards: {
                        email_format: {
                          error: custom_error_message
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        )
      end

      it 'correctly underscores the names for I18n lookup' do
        expect(subject).to eq(custom_error_message)
      end
    end
  end
end
